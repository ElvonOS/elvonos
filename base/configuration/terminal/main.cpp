// ElvonOS Terminal — a small, dependency-free terminal emulator.
//
// Implements a PTY-backed grid terminal with the ANSI sequences used by
// shells and TUI programs (SGR colours, cursor movement, erase, insert/delete,
// OSC titles, 256-colour and true-colour).  No external terminal library.
#include <QApplication>
#include <QClipboard>
#include <QFile>
#include <QHBoxLayout>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLabel>
#include <QStandardPaths>
#include <QToolButton>
#include <QVBoxLayout>
#include <QMouseEvent>
#include <QFont>
#include <QFontMetrics>
#include <QKeyEvent>
#include <QMainWindow>
#include <QMenu>
#include <QMenuBar>
#include <QMouseEvent>
#include <QPainter>
#include <QSocketNotifier>
#include <QStringDecoder>
#include <QTimer>
#include <QWidget>
#include <QWindow>

#include <fcntl.h>
#include <pty.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

#include <algorithm>
#include <vector>

namespace {

constexpr int kMaxScrollback = 4000;

struct Cell {
    QString text = QStringLiteral(" ");
    QColor fg;
    QColor bg;
    bool bold = false;
    bool underline = false;
    bool inverse = false;
};

QColor paletteColor(int index)
{
    static const QColor base[16] = {
        QColor(0x1b, 0x1f, 0x27), QColor(0xbf, 0x61, 0x6a),
        QColor(0xa3, 0xbe, 0x8c), QColor(0xeb, 0xcb, 0x8b),
        QColor(0x81, 0xa1, 0xc1), QColor(0xb4, 0x8e, 0xad),
        QColor(0x88, 0xc0, 0xd0), QColor(0xc5, 0xc8, 0xd0),
        QColor(0x4f, 0x5b, 0x66), QColor(0xbf, 0x61, 0x6a),
        QColor(0xa3, 0xbe, 0x8c), QColor(0xeb, 0xcb, 0x8b),
        QColor(0x81, 0xa1, 0xc1), QColor(0xb4, 0x8e, 0xad),
        QColor(0x88, 0xc0, 0xd0), QColor(0xe5, 0xe9, 0xf0),
    };
    if (index < 0)
        return QColor(0xd8, 0xde, 0xe9);
    if (index < 16)
        return base[index];
    if (index < 232) {
        int value = index - 16;
        int r = value / 36;
        int g = (value % 36) / 6;
        int b = value % 6;
        auto level = [](int x) { return x == 0 ? 0 : 55 + x * 40; };
        return QColor(level(r), level(g), level(b));
    }
    int grey = 8 + (index - 232) * 10;
    return QColor(grey, grey, grey);
}

class TerminalView : public QWidget {
public:
    TerminalView(QWidget *parent = nullptr) : QWidget(parent)
    {
        setFocusPolicy(Qt::StrongFocus);
        setAttribute(Qt::WA_OpaquePaintEvent);
        m_font.setFamily(QStringLiteral("DejaVu Sans Mono"));
        m_font.setStyleHint(QFont::Monospace);
        m_font.setPixelSize(14);
        m_bold = m_font;
        m_bold.setBold(true);
        m_metrics = new QFontMetrics(m_font);
        m_cursorTimer = new QTimer(this);
        m_cursorTimer->setInterval(550);
        connect(m_cursorTimer, &QTimer::timeout, this, [this] {
            m_cursorVisible = !m_cursorVisible;
            update();
        });
        m_cursorTimer->start();
    }

    ~TerminalView() override
    {
        if (m_master >= 0)
            ::close(m_master);
        delete m_metrics;
    }

    bool start(const QString &command, const QString &directory)
    {
        m_command = command;
        m_directory = directory;
        m_shell = qEnvironmentVariable("SHELL", QStringLiteral("/bin/bash"));
        m_lines.assign(1, row());
        m_cursorRow = 0;
        m_cursorCol = 0;
        updateGridSize();
        return spawn();
    }

    void setTitleCallback(std::function<void(const QString &)> callback)
    {
        m_titleCallback = std::move(callback);
    }

    void setTheme(const QColor &foreground, const QColor &background,
                  const QColor &accent)
    {
        m_defaultFg = foreground;
        m_defaultBg = background;
        m_accent = accent;
        m_currentFg = foreground;
        m_currentBg = background;
        update();
    }

protected:
    void paintEvent(QPaintEvent *) override
    {
        QPainter painter(this);
        painter.fillRect(rect(), m_defaultBg);
        const int cellW = m_metrics->horizontalAdvance(QLatin1Char('M'));
        const int cellH = m_metrics->height();
        const int visibleRows = std::max(1, height() / cellH);
        const int firstRow = std::max(0, int(m_lines.size()) - visibleRows - 1 - m_viewOffset);
        for (int row = 0; row < visibleRows; ++row) {
            const int index = firstRow + row;
            if (index < 0 || index >= int(m_lines.size()))
                continue;
            const auto &line = m_lines[index];
            for (int col = 0; col < m_cols && col < int(line.size());) {
                const Cell &cell = line[col];
                QColor bg = cell.bg.isValid() ? cell.bg : m_defaultBg;
                QColor fg = cell.fg.isValid() ? cell.fg : m_defaultFg;
                if (cell.inverse)
                    std::swap(bg, fg);
                int run = 1;
                while (col + run < int(line.size()) && col + run < m_cols
                       && line[col + run].bg == cell.bg
                       && line[col + run].fg == cell.fg
                       && line[col + run].inverse == cell.inverse)
                    ++run;
                QRect cellRect(col * cellW, row * cellH, run * cellW, cellH);
                painter.fillRect(cellRect, bg);
                QString text;
                for (int i = 0; i < run; ++i)
                    text += line[col + i].text;
                if (!text.trimmed().isEmpty()) {
                    painter.setFont(cell.bold ? m_bold : m_font);
                    painter.setPen(cell.inverse ? bg : fg);
                    painter.drawText(cellRect, Qt::AlignLeft | Qt::AlignVCenter, text);
                    if (cell.underline) {
                        painter.drawLine(cellRect.left(), cellRect.bottom() - 2,
                                         cellRect.right(), cellRect.bottom() - 2);
                    }
                }
                col += run;
            }
        }
        if (m_cursorVisible && m_viewOffset == 0) {
            const int row = m_cursorRow - firstRow;
            if (row >= 0 && row < visibleRows && m_cursorCol < m_cols) {
                QRect cursor(m_cursorCol * cellW, row * cellH, cellW, cellH);
                painter.setPen(m_accent);
                painter.drawRect(cursor.adjusted(0, 0, -1, -1));
            }
        }
    }

    void resizeEvent(QResizeEvent *) override
    {
        updateGridSize();
    }

    void keyPressEvent(QKeyEvent *event) override
    {
        const bool control = event->modifiers() & Qt::ControlModifier;
        const bool shift = event->modifiers() & Qt::ShiftModifier;
        const bool alt = event->modifiers() & Qt::AltModifier;

        if (control && shift && event->key() == Qt::Key_C) {
            copySelection();
            return;
        }
        if (control && shift && event->key() == Qt::Key_V) {
            pasteClipboard();
            return;
        }
        if (control && shift && event->key() == Qt::Key_T) {
            return;
        }
        if (shift && event->key() == Qt::Key_PageUp) {
            scroll(-1);
            return;
        }
        if (shift && event->key() == Qt::Key_PageDown) {
            scroll(1);
            return;
        }

        QByteArray sequence;
        switch (event->key()) {
        case Qt::Key_Return:
        case Qt::Key_Enter: sequence = "\r"; break;
        case Qt::Key_Backspace: sequence = "\x7f"; break;
        case Qt::Key_Tab: sequence = "\t"; break;
        case Qt::Key_Escape: sequence = "\x1b"; break;
        case Qt::Key_Up: sequence = "\x1b[A"; break;
        case Qt::Key_Down: sequence = "\x1b[B"; break;
        case Qt::Key_Right: sequence = "\x1b[C"; break;
        case Qt::Key_Left: sequence = "\x1b[D"; break;
        case Qt::Key_Home: sequence = "\x1b[H"; break;
        case Qt::Key_End: sequence = "\x1b[F"; break;
        case Qt::Key_PageUp: sequence = "\x1b[5~"; break;
        case Qt::Key_PageDown: sequence = "\x1b[6~"; break;
        case Qt::Key_Insert: sequence = "\x1b[2~"; break;
        case Qt::Key_Delete: sequence = "\x1b[3~"; break;
        case Qt::Key_F1: sequence = "\x1bOP"; break;
        case Qt::Key_F2: sequence = "\x1bOQ"; break;
        case Qt::Key_F3: sequence = "\x1bOR"; break;
        case Qt::Key_F4: sequence = "\x1bOS"; break;
        case Qt::Key_F5: sequence = "\x1b[15~"; break;
        case Qt::Key_F6: sequence = "\x1b[17~"; break;
        case Qt::Key_F7: sequence = "\x1b[18~"; break;
        case Qt::Key_F8: sequence = "\x1b[19~"; break;
        case Qt::Key_F9: sequence = "\x1b[20~"; break;
        case Qt::Key_F10: sequence = "\x1b[21~"; break;
        case Qt::Key_F11: sequence = "\x1b[23~"; break;
        case Qt::Key_F12: sequence = "\x1b[24~"; break;
        default: break;
        }

        if (sequence.isEmpty()) {
            if (control) {
                const int key = event->key();
                if (key >= Qt::Key_A && key <= Qt::Key_Z)
                    sequence = QByteArray(1, char(key - Qt::Key_A + 1));
                else if (key == Qt::Key_Space)
                    sequence = QByteArray(1, char(0));
            } else if (!event->text().isEmpty()) {
                sequence = event->text().toUtf8();
                if (alt)
                    sequence.prepend('\x1b');
            }
        }
        if (!sequence.isEmpty() && m_master >= 0) {
            ::write(m_master, sequence.constData(), sequence.size());
            m_viewOffset = 0;
            update();
        }
    }

    void mousePressEvent(QMouseEvent *event) override
    {
        m_selecting = true;
        m_selectionStart = cellAt(event->pos());
        m_selectionEnd = m_selectionStart;
        update();
    }

    void mouseMoveEvent(QMouseEvent *event) override
    {
        if (!m_selecting)
            return;
        m_selectionEnd = cellAt(event->pos());
        update();
    }

    void mouseReleaseEvent(QMouseEvent *) override
    {
        m_selecting = false;
    }

    void wheelEvent(QWheelEvent *event) override
    {
        scroll(event->angleDelta().y() > 0 ? -3 : 3);
    }

private:
    struct Position { int row = 0; int col = 0; };

    std::vector<Cell> row()
    {
        std::vector<Cell> line(m_cols);
        for (auto &cell : line) {
            cell.fg = m_defaultFg;
            cell.bg = m_defaultBg;
        }
        return line;
    }

    bool spawn()
    {
        struct winsize size {};
        size.ws_row = m_rows;
        size.ws_col = m_cols;
        int master = -1;
        pid_t pid = forkpty(&master, nullptr, nullptr, &size);
        if (pid < 0)
            return false;
        if (pid == 0) {
            if (!m_directory.isEmpty())
                chdir(m_directory.toUtf8().constData());
            setenv("TERM", "xterm-256color", 1);
            setenv("COLORTERM", "truecolor", 1);
            setenv("LANG", qEnvironmentVariable("LANG", "C.UTF-8").toUtf8().constData(), 1);
            if (!m_command.isEmpty()) {
                execl("/bin/sh", "sh", "-c", m_command.toUtf8().constData(),
                      static_cast<char *>(nullptr));
            } else {
                execl(m_shell.toUtf8().constData(), m_shell.toUtf8().constData(),
                      "-l", static_cast<char *>(nullptr));
            }
            _exit(127);
        }
        m_master = master;
        fcntl(m_master, F_SETFL, fcntl(m_master, F_GETFL) | O_NONBLOCK);
        m_notifier = new QSocketNotifier(m_master, QSocketNotifier::Read, this);
        connect(m_notifier, &QSocketNotifier::activated, this, [this] { readOutput(); });
        return true;
    }

    void updateGridSize()
    {
        const int cellW = std::max(1, m_metrics->horizontalAdvance(QLatin1Char('M')));
        const int cellH = std::max(1, m_metrics->height());
        const int cols = std::max(20, (width() - 8) / cellW);
        const int rows = std::max(5, height() / cellH);
        const bool changed = cols != m_cols || rows != m_rows;
        m_cols = cols;
        m_rows = rows;
        for (auto &line : m_lines)
            line.resize(m_cols, Cell{QStringLiteral(" "), m_defaultFg, m_defaultBg});
        while (int(m_lines.size()) < m_rows)
            m_lines.push_back(row());
        m_cursorRow = std::min(m_cursorRow, int(m_lines.size()) - 1);
        m_cursorCol = std::min(m_cursorCol, m_cols - 1);
        if (changed && m_master >= 0) {
            struct winsize size {};
            size.ws_row = m_rows;
            size.ws_col = m_cols;
            ioctl(m_master, TIOCSWINSZ, &size);
        }
    }

    Position cellAt(const QPoint &point)
    {
        const int cellW = std::max(1, m_metrics->horizontalAdvance(QLatin1Char('M')));
        const int cellH = std::max(1, m_metrics->height());
        const int visibleRows = std::max(1, height() / cellH);
        const int firstRow = std::max(0, int(m_lines.size()) - visibleRows - 1 - m_viewOffset);
        Position position;
        position.col = std::clamp(point.x() / cellW, 0, m_cols - 1);
        position.row = std::clamp(firstRow + point.y() / cellH, 0, int(m_lines.size()) - 1);
        return position;
    }

public:
    void copySelection()
    {
        if (m_selectionStart.row > m_selectionEnd.row
            || (m_selectionStart.row == m_selectionEnd.row
                && m_selectionStart.col > m_selectionEnd.col))
            std::swap(m_selectionStart, m_selectionEnd);
        QString text;
        for (int row = m_selectionStart.row; row <= m_selectionEnd.row; ++row) {
            if (row < 0 || row >= int(m_lines.size()))
                continue;
            int start = row == m_selectionStart.row ? m_selectionStart.col : 0;
            int end = row == m_selectionEnd.row ? m_selectionEnd.col : m_cols - 1;
            for (int col = start; col <= end && col < int(m_lines[row].size()); ++col)
                text += m_lines[row][col].text;
            if (row != m_selectionEnd.row)
                text += QLatin1Char('\n');
        }
        QApplication::clipboard()->setText(text);
    }

    void pasteClipboard()
    {
        const QString text = QApplication::clipboard()->text();
        if (!text.isEmpty() && m_master >= 0) {
            const QByteArray data = text.toUtf8();
            ::write(m_master, data.constData(), data.size());
            update();
        }
    }

private:
    void scroll(int delta)
    {
        const int maximum = std::max(0, int(m_lines.size()) - m_rows);
        m_viewOffset = std::clamp(m_viewOffset - delta, 0, maximum);
        update();
    }

    void readOutput()
    {
        char buffer[8192];
        ssize_t count;
        while ((count = ::read(m_master, buffer, sizeof(buffer))) > 0) {
            feed(m_decoder.decode(QByteArray(buffer, int(count))));
            update();
        }
        if (count == 0) {
            m_notifier->setEnabled(false);
            if (QWidget *top = window())
                QMetaObject::invokeMethod(top, "close", Qt::QueuedConnection);
        }
    }

    void putChar(QChar character)
    {
        if (m_cursorRow < 0)
            m_cursorRow = 0;
        while (int(m_lines.size()) <= m_cursorRow)
            m_lines.push_back(row());
        auto &line = m_lines[m_cursorRow];
        if (int(line.size()) <= m_cursorCol)
            line.resize(m_cursorCol + 1, Cell{QStringLiteral(" "), m_defaultFg, m_defaultBg});
        Cell &cell = line[m_cursorCol];
        cell.text = QString(character);
        cell.fg = m_currentFg;
        cell.bg = m_currentBg;
        cell.bold = m_boldActive;
        cell.underline = m_underline;
        cell.inverse = m_inverse;
        ++m_cursorCol;
        if (m_cursorCol >= m_cols) {
            m_cursorCol = 0;
            newLine();
        }
    }

    void newLine()
    {
        ++m_cursorRow;
        if (m_cursorRow >= int(m_lines.size()))
            m_lines.push_back(row());
        trimScrollback();
    }

    void trimScrollback()
    {
        const int maximum = kMaxScrollback + m_rows;
        if (int(m_lines.size()) > maximum) {
            const int remove = int(m_lines.size()) - maximum;
            m_lines.erase(m_lines.begin(), m_lines.begin() + remove);
            m_cursorRow = std::max(0, m_cursorRow - remove);
            if (m_selectionStart.row >= remove)
                m_selectionStart.row -= remove;
            if (m_selectionEnd.row >= remove)
                m_selectionEnd.row -= remove;
        }
    }

    void feed(const QString &text)
    {
        for (QChar character : text) {
            const ushort code = character.unicode();
            if (m_state == State::Normal) {
                if (code == 0x1b) {
                    m_state = State::Escape;
                } else if (code == '\n') {
                    newLine();
                } else if (code == '\r') {
                    m_cursorCol = 0;
                } else if (code == '\b') {
                    if (m_cursorCol > 0)
                        --m_cursorCol;
                } else if (code == '\t') {
                    m_cursorCol = std::min(m_cols - 1, (m_cursorCol / 8 + 1) * 8);
                } else if (code == 0x07) {
                    QApplication::beep();
                } else if (code >= 0x20) {
                    putChar(character);
                }
            } else if (m_state == State::Escape) {
                if (code == '[') {
                    m_state = State::Csi;
                    m_params.clear();
                } else if (code == ']') {
                    m_state = State::Osc;
                    m_osc.clear();
                } else if (code == '7' || code == '8') {
                    m_state = State::Normal;
                } else if (code == '(' || code == ')' || code == '#') {
                    m_state = State::Charset;
                } else {
                    m_state = State::Normal;
                }
            } else if (m_state == State::Charset) {
                m_state = State::Normal;
            } else if (m_state == State::Osc) {
                if (code == 0x07) {
                    m_state = State::Normal;
                    handleOsc();
                } else if (code == 0x1b) {
                    m_state = State::OscEscape;
                } else {
                    m_osc += character;
                }
            } else if (m_state == State::OscEscape) {
                m_state = State::Normal;
                handleOsc();
            } else if (m_state == State::Csi) {
                if (code >= 0x40 && code <= 0x7e) {
                    handleCsi(character);
                    m_state = State::Normal;
                } else {
                    m_params += character;
                }
            }
        }
    }

    void handleOsc()
    {
        const int separator = m_osc.indexOf(QLatin1Char(';'));
        if (separator > 0) {
            const int command = m_osc.left(separator).toInt();
            if ((command == 0 || command == 2) && m_titleCallback)
                m_titleCallback(m_osc.mid(separator + 1));
        }
    }

    QVector<int> paramList() const
    {
        QVector<int> values;
        QString normalized = m_params;
        if (normalized.startsWith(QLatin1Char('?'))
            || normalized.startsWith(QLatin1Char('>'))
            || normalized.startsWith(QLatin1Char('<')))
            normalized.remove(0, 1);
        for (const QString &part : normalized.split(QLatin1Char(';')))
            values.append(part.isEmpty() ? 0 : part.toInt());
        if (values.isEmpty())
            values.append(0);
        return values;
    }

    void handleCsi(QChar final)
    {
        const QVector<int> values = paramList();
        const int first = values.value(0);
        const int second = values.value(1);
        switch (final.unicode()) {
        case 'm': {
            for (int index = 0; index < values.size(); ++index) {
                const int value = values[index];
                if (value == 0) {
                    m_currentFg = m_defaultFg;
                    m_currentBg = m_defaultBg;
                    m_boldActive = false;
                    m_underline = false;
                    m_inverse = false;
                } else if (value == 1) {
                    m_boldActive = true;
                } else if (value == 4) {
                    m_underline = true;
                } else if (value == 7) {
                    m_inverse = true;
                } else if (value == 22) {
                    m_boldActive = false;
                } else if (value == 24) {
                    m_underline = false;
                } else if (value == 27) {
                    m_inverse = false;
                } else if (value >= 30 && value <= 37) {
                    m_currentFg = paletteColor(value - 30);
                } else if (value >= 90 && value <= 97) {
                    m_currentFg = paletteColor(value - 90 + 8);
                } else if (value >= 40 && value <= 47) {
                    m_currentBg = paletteColor(value - 40);
                } else if (value >= 100 && value <= 107) {
                    m_currentBg = paletteColor(value - 100 + 8);
                } else if (value == 39) {
                    m_currentFg = m_defaultFg;
                } else if (value == 49) {
                    m_currentBg = m_defaultBg;
                } else if (value == 38 || value == 48) {
                    QColor color;
                    if (values.value(index + 1) == 5 && index + 2 < values.size()) {
                        color = paletteColor(values[index + 2]);
                        index += 2;
                    } else if (values.value(index + 1) == 2 && index + 4 < values.size()) {
                        color = QColor(values[index + 2], values[index + 3], values[index + 4]);
                        index += 4;
                    }
                    if (color.isValid()) {
                        if (value == 38)
                            m_currentFg = color;
                        else
                            m_currentBg = color;
                    }
                }
            }
            break;
        }
        case 'A':
            m_cursorRow = std::max(0, m_cursorRow - std::max(1, first));
            trimCursor();
            break;
        case 'B':
            m_cursorRow = std::min(int(m_lines.size()) - 1, m_cursorRow + std::max(1, first));
            trimCursor();
            break;
        case 'C':
            m_cursorCol = std::min(m_cols - 1, m_cursorCol + std::max(1, first));
            break;
        case 'D':
            m_cursorCol = std::max(0, m_cursorCol - std::max(1, first));
            break;
        case 'E':
            m_cursorRow = std::min(int(m_lines.size()) - 1, m_cursorRow + std::max(1, first));
            m_cursorCol = 0;
            break;
        case 'F':
            m_cursorRow = std::max(0, m_cursorRow - std::max(1, first));
            m_cursorCol = 0;
            break;
        case 'G':
            m_cursorCol = std::clamp(first - 1, 0, m_cols - 1);
            break;
        case 'H':
        case 'f':
            m_cursorRow = std::clamp(first - 1, 0, std::max(0, int(m_lines.size()) - 1));
            m_cursorCol = std::clamp(second - 1, 0, m_cols - 1);
            trimCursor();
            break;
        case 'd':
            m_cursorRow = std::clamp(first - 1, 0, std::max(0, int(m_lines.size()) - 1));
            break;
        case 'J': {
            if (first == 2 || first == 3) {
                m_lines.assign(1, row());
                m_cursorRow = 0;
                m_cursorCol = 0;
            } else if (first == 0) {
                if (m_cursorRow < int(m_lines.size())) {
                    for (int col = m_cursorCol; col < m_cols; ++col)
                        m_lines[m_cursorRow][col] = Cell{QStringLiteral(" "), m_defaultFg, m_defaultBg};
                    m_lines.erase(m_lines.begin() + m_cursorRow + 1, m_lines.end());
                }
            }
            break;
        }
        case 'K': {
            if (m_cursorRow < int(m_lines.size())) {
                int start = first == 0 ? m_cursorCol : 0;
                int end = (first == 0 || first == 1) ? m_cols : m_cursorCol;
                for (int col = start; col < end && col < m_cols; ++col)
                    m_lines[m_cursorRow][col] = Cell{QStringLiteral(" "), m_defaultFg, m_defaultBg};
            }
            break;
        }
        case 'L': {
            int count = std::max(1, first);
            count = std::min(count, m_rows);
            m_lines.insert(m_lines.begin() + m_cursorRow, count, row());
            trimScrollback();
            break;
        }
        case 'M': {
            int count = std::max(1, first);
            for (int index = 0; index < count && m_cursorRow < int(m_lines.size()); ++index)
                m_lines.erase(m_lines.begin() + m_cursorRow);
            while (int(m_lines.size()) < m_cursorRow + m_rows)
                m_lines.push_back(row());
            break;
        }
        case 'P': {
            if (m_cursorRow < int(m_lines.size())) {
                int count = std::max(1, first);
                auto &line = m_lines[m_cursorRow];
                line.erase(line.begin() + std::min(m_cursorCol, int(line.size())),
                           line.begin() + std::min(m_cursorCol + count, int(line.size())));
                line.resize(m_cols);
            }
            break;
        }
        case '@': {
            if (m_cursorRow < int(m_lines.size())) {
                int count = std::max(1, first);
                auto &line = m_lines[m_cursorRow];
                line.insert(line.begin() + std::min(m_cursorCol, int(line.size())), count,
                            Cell{QStringLiteral(" "), m_defaultFg, m_defaultBg});
                line.resize(m_cols);
            }
            break;
        }
        default:
            break;
        }
    }

    void trimCursor()
    {
        if (m_cursorRow < 0)
            m_cursorRow = 0;
        if (m_cursorRow >= int(m_lines.size()))
            m_cursorRow = int(m_lines.size()) - 1;
    }

    enum class State { Normal, Escape, Charset, Csi, Osc, OscEscape };

    int m_master = -1;
    QSocketNotifier *m_notifier = nullptr;
    QString m_command;
    QString m_directory;
    QString m_shell;
    int m_rows = 24;
    int m_cols = 80;
    int m_cursorRow = 0;
    int m_cursorCol = 0;
    int m_viewOffset = 0;
    bool m_boldActive = false;
    bool m_underline = false;
    bool m_inverse = false;
    bool m_cursorVisible = true;
    bool m_selecting = false;
    Position m_selectionStart;
    Position m_selectionEnd;
    std::vector<std::vector<Cell>> m_lines;
    QColor m_defaultFg = QColor(0xd8, 0xde, 0xe9);
    QColor m_accent = QColor(0x8F, 0xD3, 0xFF);
    QColor m_defaultBg = QColor(0x14, 0x18, 0x20);
    QColor m_currentFg = m_defaultFg;
    QColor m_currentBg;
    QFont m_font;
    QFont m_bold;
    QFontMetrics *m_metrics = nullptr;
    QTimer *m_cursorTimer = nullptr;
    QStringDecoder m_decoder{QStringDecoder::Utf8};
    State m_state = State::Normal;
    QString m_params;
    QString m_osc;
    std::function<void(const QString &)> m_titleCallback;
};

struct Theme {
    QColor accent = QColor(0x8F, 0xD3, 0xFF);
    QColor accent2 = QColor(0x4C, 0xC2, 0xFF);
    QColor background = QColor(0x10, 0x10, 0x16);
    QColor panel = QColor(0x15, 0x15, 0x1C);
    QColor surface = QColor(0x1B, 0x1B, 0x26);
    QColor text = QColor(0xE9, 0xEC, 0xF2);
    QColor muted = QColor(0x8B, 0x93, 0xA1);
    QColor border = QColor(0xFF, 0xFF, 0xFF);
    int radius = 14;
};

static Theme loadTheme()
{
    Theme theme;
    QFile file(QStandardPaths::writableLocation(
                   QStandardPaths::GenericConfigLocation)
               + QStringLiteral("/elvonos/theme.json"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return theme;
    const QJsonObject object = QJsonDocument::fromJson(file.readAll()).object();
    auto color = [&object](const char *key, const QColor &fallback) {
        const QColor parsed(object.value(QLatin1String(key)).toString());
        return parsed.isValid() ? parsed : fallback;
    };
    theme.accent = color("accent", theme.accent);
    theme.accent2 = color("accent2", theme.accent2);
    theme.background = color("background", theme.background);
    theme.panel = color("panel", theme.panel);
    theme.surface = color("surface", theme.surface);
    theme.text = color("text", theme.text);
    theme.muted = color("muted", theme.muted);
    theme.border = color("border", theme.border);
    theme.radius = qBound(0, object.value(QStringLiteral("radius")).toInt(theme.radius), 28);
    return theme;
}

class TitleBar : public QWidget {
public:
    TitleBar(const Theme &theme, QWidget *parent = nullptr)
        : QWidget(parent), m_theme(theme)
    {
        setFixedHeight(36);
        auto *layout = new QHBoxLayout(this);
        layout->setContentsMargins(6, 0, 6, 0);
        layout->setSpacing(2);
        m_menu = makeButton(QString::fromUtf8("\u2630"));
        m_menu->setToolTip(QObject::tr("Menu"));
        m_title = new QLabel(QStringLiteral("Terminal"), this);
        m_title->setAlignment(Qt::AlignCenter);
        m_title->setStyleSheet(QStringLiteral(
            "color:%1;font-size:11px;background:transparent;")
            .arg(theme.text.name()));
        m_min = makeButton(QString::fromUtf8("\u2500"));
        m_max = makeButton(QString::fromUtf8("\u25A1"));
        m_close = makeButton(QString::fromUtf8("\u2715"));
        layout->addWidget(m_menu);
        layout->addWidget(m_title, 1);
        layout->addWidget(m_min);
        layout->addWidget(m_max);
        layout->addWidget(m_close);
    }

    QToolButton *menuButton() const { return m_menu; }
    QToolButton *minimizeButton() const { return m_min; }
    QToolButton *maximizeButton() const { return m_max; }
    QToolButton *closeButton() const { return m_close; }
    void setTitle(const QString &title) { m_title->setText(title); }

protected:
    void mousePressEvent(QMouseEvent *event) override
    {
        if (event->button() == Qt::LeftButton) {
            m_dragOffset = event->globalPosition().toPoint()
                           - window()->frameGeometry().topLeft();
            event->accept();
        }
    }
    void mouseMoveEvent(QMouseEvent *event) override
    {
        if ((event->buttons() & Qt::LeftButton) && !m_dragOffset.isNull()) {
            window()->move(event->globalPosition().toPoint() - m_dragOffset);
            event->accept();
        }
    }
    void mouseReleaseEvent(QMouseEvent *) override { m_dragOffset = QPoint(); }
    void mouseDoubleClickEvent(QMouseEvent *) override
    {
        if (window()->isMaximized())
            window()->showNormal();
        else
            window()->showMaximized();
    }

private:
    QToolButton *makeButton(const QString &text)
    {
        auto *button = new QToolButton(this);
        button->setText(text);
        button->setAutoRaise(true);
        button->setCursor(Qt::PointingHandCursor);
        button->setFixedSize(28, 26);
        button->setStyleSheet(QStringLiteral(
            "QToolButton{color:%1;background:transparent;border:none;"
            "border-radius:6px;font-size:12px;}"
            "QToolButton:hover{background:rgba(255,255,255,0.10);}"
            "QToolButton:pressed{background:%2;color:%3;}")
            .arg(m_theme.muted.name(), m_theme.accent.name(),
                 m_theme.background.name()));
        return button;
    }

    Theme m_theme;
    QLabel *m_title = nullptr;
    QToolButton *m_menu = nullptr;
    QToolButton *m_min = nullptr;
    QToolButton *m_max = nullptr;
    QToolButton *m_close = nullptr;
    QPoint m_dragOffset;
};

class TerminalWindow : public QMainWindow {
public:
    TerminalWindow(const QString &command, const QString &title,
                   const QString &directory = QString(), QWidget *parent = nullptr)
        : QMainWindow(parent)
    {
        m_theme = loadTheme();
        setWindowFlags(Qt::FramelessWindowHint | Qt::Window);
        setAttribute(Qt::WA_TranslucentBackground);

        auto *frame = new QWidget(this);
        frame->setObjectName(QStringLiteral("terminalFrame"));
        frame->setStyleSheet(QStringLiteral(
            "QWidget#terminalFrame{background:%1;"
            "border:1px solid rgba(255,255,255,0.16);border-radius:%2px;}")
            .arg(m_theme.background.name()).arg(m_theme.radius));
        setCentralWidget(frame);

        auto *layout = new QVBoxLayout(frame);
        layout->setContentsMargins(8, 8, 8, 8);
        layout->setSpacing(6);
        m_bar = new TitleBar(m_theme, frame);
        layout->addWidget(m_bar);
        m_view = new TerminalView(frame);
        m_view->setTheme(m_theme.text, m_theme.background, m_theme.accent);
        layout->addWidget(m_view, 1);

        setWindowTitle(title);
        m_bar->setTitle(title);
        resize(920, 580);

        m_view->setTitleCallback([this](const QString &value) {
            if (!value.isEmpty()) {
                setWindowTitle(value);
                m_bar->setTitle(value);
            }
        });
        buildMenu();
        connect(m_bar->minimizeButton(), &QToolButton::clicked,
                this, &QWidget::showMinimized);
        connect(m_bar->maximizeButton(), &QToolButton::clicked, this, [this] {
            if (isMaximized())
                showNormal();
            else
                showMaximized();
        });
        connect(m_bar->closeButton(), &QToolButton::clicked,
                this, &QWidget::close);

        m_view->start(command, directory);
        m_view->setFocus();
    }

private:
    void buildMenu()
    {
        auto *menu = new QMenu(this);
        auto *newWindow = menu->addAction(QObject::tr("New Window"));
        connect(newWindow, &QAction::triggered, this, [] {
            auto *window = new TerminalWindow(QString(), QStringLiteral("Terminal"));
            window->show();
        });
        auto *android = menu->addAction(QObject::tr("Android Shell"));
        connect(android, &QAction::triggered, this, [] {
            auto *window = new TerminalWindow(
                QStringLiteral("sudo -n lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh"),
                QStringLiteral("Android Shell"));
            window->show();
        });
        menu->addSeparator();
        auto *copy = menu->addAction(QObject::tr("Copy"));
        copy->setShortcut(QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_C));
        connect(copy, &QAction::triggered, this, [this] { m_view->copySelection(); });
        auto *paste = menu->addAction(QObject::tr("Paste"));
        paste->setShortcut(QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_V));
        connect(paste, &QAction::triggered, this, [this] { m_view->pasteClipboard(); });
        menu->addSeparator();
        auto *close = menu->addAction(QObject::tr("Close"));
        connect(close, &QAction::triggered, this, &QWidget::close);
        m_bar->menuButton()->setMenu(menu);
        m_bar->menuButton()->setPopupMode(QToolButton::InstantPopup);
    }

    Theme m_theme;
    TitleBar *m_bar = nullptr;
    TerminalView *m_view = nullptr;
};

} // namespace

int main(int argc, char **argv)
{
    QApplication application(argc, argv);
    application.setStyle(QStringLiteral("Fusion"));
    QPalette palette;
    palette.setColor(QPalette::Window, QColor(0x14, 0x18, 0x20));
    palette.setColor(QPalette::WindowText, QColor(0xd8, 0xde, 0xe9));
    palette.setColor(QPalette::Base, QColor(0x14, 0x18, 0x20));
    palette.setColor(QPalette::AlternateBase, QColor(0x1b, 0x1f, 0x27));
    palette.setColor(QPalette::Text, QColor(0xd8, 0xde, 0xe9));
    palette.setColor(QPalette::Button, QColor(0x1b, 0x1f, 0x27));
    palette.setColor(QPalette::ButtonText, QColor(0xd8, 0xde, 0xe9));
    palette.setColor(QPalette::Highlight, QColor(0x2b, 0x5b, 0x8a));
    palette.setColor(QPalette::HighlightedText, QColor(0xff, 0xff, 0xff));
    application.setPalette(palette);
    application.setStyleSheet(QStringLiteral(
        "QMenuBar{background:#141820;color:#d8dee9;}"
        "QMenuBar::item{background:transparent;padding:4px 10px;}"
        "QMenuBar::item:selected{background:#2b5b8a;border-radius:4px;}"
        "QMenu{background:#1b1f27;color:#d8dee9;border:1px solid #2a3342;}"
        "QMenu::item:selected{background:#2b5b8a;}"));
    application.setApplicationName(QStringLiteral("elvonos-terminal"));
    application.setApplicationDisplayName(QStringLiteral("Terminal"));

    QString command;
    QString title = QStringLiteral("Terminal");
    QString directory;
    bool android = false;
    const QStringList arguments = application.arguments();
    for (int index = 1; index < arguments.size(); ++index) {
        const QString &argument = arguments[index];
        if ((argument == QStringLiteral("--command") || argument == QStringLiteral("-e"))
            && index + 1 < arguments.size()) {
            command = arguments[++index];
        } else if (argument == QStringLiteral("--android")) {
            android = true;
        } else if (argument == QStringLiteral("--title") && index + 1 < arguments.size()) {
            title = arguments[++index];
        } else if ((argument == QStringLiteral("--working-directory")
                    || argument == QStringLiteral("-d"))
                   && index + 1 < arguments.size()) {
            directory = arguments[++index];
        }
    }
    if (android) {
        command = QStringLiteral(
            "sudo -n lxc-attach -P /var/lib/waydroid/lxc -n waydroid -- /system/bin/sh");
        title = QStringLiteral("Android Shell");
    }

    TerminalWindow window(command, title, directory);
    window.show();
    return application.exec();
}
