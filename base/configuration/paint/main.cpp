#include <QColor>
#include <QCursor>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QFont>
#include <QGuiApplication>
#include <QHoverEvent>
#include <QImage>
#include <QMouseEvent>
#include <QPainter>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickPaintedItem>
#include <QStandardPaths>
#include <QTransform>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QWheelEvent>
#include <QtQml/qqml.h>

#include <algorithm>
#include <cmath>
#include "../common/elvonapp.h"

namespace {

bool colorMatches(QRgb a, QRgb b)
{
    const int tolerance = 12;
    return std::abs(qRed(a) - qRed(b)) <= tolerance
           && std::abs(qGreen(a) - qGreen(b)) <= tolerance
           && std::abs(qBlue(a) - qBlue(b)) <= tolerance
           && std::abs(qAlpha(a) - qAlpha(b)) <= tolerance;
}

struct Layer {
    QImage image;
    QString name;
    bool visible = true;
    qreal opacity = 1.0;
};

struct Snapshot {
    QList<Layer> layers;
    int active = 0;
};

} // namespace

class PaintCanvas : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QString tool READ tool WRITE setTool NOTIFY toolChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(QColor backgroundColor READ backgroundColor WRITE setBackgroundColor NOTIFY backgroundColorChanged)
    Q_PROPERTY(int brushSize READ brushSize WRITE setBrushSize NOTIFY brushSizeChanged)
    Q_PROPERTY(bool shapeFill READ shapeFill WRITE setShapeFill NOTIFY shapeFillChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY historyChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY historyChanged)
    Q_PROPERTY(bool dirty READ dirty NOTIFY dirtyChanged)
    Q_PROPERTY(int imageWidth READ imageWidth NOTIFY imageChanged)
    Q_PROPERTY(int imageHeight READ imageHeight NOTIFY imageChanged)
    Q_PROPERTY(int cursorX READ cursorX NOTIFY cursorChanged)
    Q_PROPERTY(int cursorY READ cursorY NOTIFY cursorChanged)
    Q_PROPERTY(QString savedPath READ savedPath NOTIFY savedPathChanged)
    Q_PROPERTY(QVariantList layerList READ layerList NOTIFY layersChanged)
    Q_PROPERTY(int activeLayer READ activeLayer NOTIFY layersChanged)
    Q_PROPERTY(qreal layerOpacity READ layerOpacity WRITE setLayerOpacity NOTIFY layersChanged)
    Q_PROPERTY(int layerCount READ layerCount NOTIFY layersChanged)
    Q_PROPERTY(qreal viewZoom READ viewZoom WRITE setViewZoom NOTIFY viewChanged)

public:
    explicit PaintCanvas(QQuickItem *parent = nullptr) : QQuickPaintedItem(parent)
    {
        setAcceptedMouseButtons(Qt::LeftButton | Qt::MiddleButton);
        setAcceptHoverEvents(true);
        setCursor(QCursor(Qt::CrossCursor));
        setAntialiasing(true);
        resetDocument();
    }

    QString tool() const { return m_tool; }
    void setTool(const QString &value)
    {
        if (m_tool == value)
            return;
        m_tool = value;
        m_previewActive = false;
        update();
        emit toolChanged();
    }

    QColor color() const { return m_color; }
    void setColor(const QColor &value)
    {
        if (m_color == value)
            return;
        m_color = value;
        emit colorChanged();
    }

    QColor backgroundColor() const { return m_backgroundColor; }
    void setBackgroundColor(const QColor &value)
    {
        if (m_backgroundColor == value)
            return;
        m_backgroundColor = value;
        update();
        emit backgroundColorChanged();
    }

    int brushSize() const { return m_brushSize; }
    void setBrushSize(int value)
    {
        const int clamped = qBound(1, value, 96);
        if (m_brushSize == clamped)
            return;
        m_brushSize = clamped;
        emit brushSizeChanged();
    }

    bool shapeFill() const { return m_shapeFill; }
    void setShapeFill(bool value)
    {
        if (m_shapeFill == value)
            return;
        m_shapeFill = value;
        emit shapeFillChanged();
    }

    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }
    bool dirty() const { return m_dirty; }
    int imageWidth() const { return m_width; }
    int imageHeight() const { return m_height; }
    int cursorX() const { return m_cursorX; }
    int cursorY() const { return m_cursorY; }
    QString savedPath() const { return m_savedPath; }
    int layerCount() const { return m_layers.size(); }
    int activeLayer() const { return m_active; }

    qreal layerOpacity() const
    {
        return (m_active >= 0 && m_active < m_layers.size())
                   ? m_layers.at(m_active).opacity : 1.0;
    }

    void setLayerOpacity(qreal value)
    {
        if (m_active < 0 || m_active >= m_layers.size())
            return;
        const qreal clamped = qBound<qreal>(0.0, value, 1.0);
        if (qFuzzyCompare(m_layers.at(m_active).opacity, clamped))
            return;
        m_layers[m_active].opacity = clamped;
        m_compositeDirty = true;
        setDirty(true);
        emit layersChanged();
        update();
    }

    QVariantList layerList() const
    {
        QVariantList result;
        for (int i = m_layers.size() - 1; i >= 0; --i) {
            const Layer &layer = m_layers.at(i);
            QVariantMap map;
            map.insert("index", i);
            map.insert("name", layer.name);
            map.insert("visible", layer.visible);
            map.insert("opacity", layer.opacity);
            map.insert("active", i == m_active);
            result.append(map);
        }
        return result;
    }

    qreal viewZoom() const { return m_viewZoom; }
    void setViewZoom(qreal value)
    {
        const qreal clamped = qBound<qreal>(0.25, value, 8.0);
        if (qFuzzyCompare(m_viewZoom, clamped))
            return;
        m_viewZoom = clamped;
        update();
        emit viewChanged();
    }

    Q_INVOKABLE void zoomIn()
    {
        setViewZoom(m_viewZoom * 1.25);
    }

    Q_INVOKABLE void zoomOut()
    {
        setViewZoom(m_viewZoom / 1.25);
    }

    Q_INVOKABLE void resetView()
    {
        m_offset = QPointF();
        setViewZoom(1.0);
        update();
    }

    Q_INVOKABLE void flipHorizontal()
    {
        pushUndo();
        for (Layer &layer : m_layers)
            layer.image = layer.image.mirrored(true, false);
        finishEdit();
        emit layersChanged();
    }

    Q_INVOKABLE void flipVertical()
    {
        pushUndo();
        for (Layer &layer : m_layers)
            layer.image = layer.image.mirrored(false, true);
        finishEdit();
        emit layersChanged();
    }

    Q_INVOKABLE void rotateCanvas()
    {
        pushUndo();
        for (Layer &layer : m_layers) {
            const QImage rotated = layer.image.transformed(QTransform().rotate(90));
            layer.image = rotated;
        }
        if (!m_layers.isEmpty()) {
            m_width = m_layers.first().image.width();
            m_height = m_layers.first().image.height();
        }
        m_compositeDirty = true;
        resetView();
        finishEdit();
        emit imageChanged();
        emit layersChanged();
    }

    Q_INVOKABLE void resizeCanvas(int width, int height)
    {
        const int newWidth = qBound(64, width, 4096);
        const int newHeight = qBound(64, height, 4096);
        if (newWidth == m_width && newHeight == m_height)
            return;
        pushUndo();
        for (Layer &layer : m_layers) {
            layer.image = layer.image.scaled(newWidth, newHeight,
                                             Qt::IgnoreAspectRatio,
                                             Qt::SmoothTransformation);
        }
        m_width = newWidth;
        m_height = newHeight;
        m_compositeDirty = true;
        resetView();
        finishEdit();
        emit imageChanged();
        emit layersChanged();
    }

    Q_INVOKABLE void renameLayer(int index, const QString &name)
    {
        if (index < 0 || index >= m_layers.size() || name.trimmed().isEmpty())
            return;
        m_layers[index].name = name.trimmed();
        emit layersChanged();
    }

    Q_INVOKABLE void insertText(const QString &text)
    {
        if (text.isEmpty() || m_textPoint.x() < 0 || m_active < 0
            || m_active >= m_layers.size())
            return;
        pushUndo();
        QPainter painter(&m_layers[m_active].image);
        painter.setRenderHint(QPainter::Antialiasing, true);
        QFont font(QStringLiteral("Sans"));
        font.setPixelSize(std::max(10, m_brushSize * 2));
        painter.setFont(font);
        painter.setPen(m_color);
        painter.drawText(m_textPoint, text);
        painter.end();
        m_textPoint = QPointF(-1, -1);
        finishEdit();
        emit layersChanged();
    }

    void paint(QPainter *painter) override
    {
        painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
        const QRectF target = imageTargetRect();
        if (target.isEmpty())
            return;

        if (m_compositeDirty)
            rebuildComposite();

        painter->fillRect(boundingRect(), m_backgroundColor);
        painter->drawImage(target, m_composite);

        if (m_previewActive && m_active >= 0 && m_active < m_layers.size()
            && m_layers.at(m_active).visible) {
            QPen pen(m_color);
            const qreal scale = target.width() / std::max(1, m_width);
            pen.setWidthF(std::max<qreal>(1.0, m_brushSize * scale));
            pen.setCapStyle(Qt::RoundCap);
            pen.setJoinStyle(Qt::RoundJoin);
            painter->setPen(pen);
            painter->setRenderHint(QPainter::Antialiasing, true);
            if (m_shapeFill && m_tool != "line")
                painter->setBrush(m_color);
            const QPointF start = imageToItem(m_start);
            const QPointF end = imageToItem(m_end);
            if (m_tool == "line") {
                painter->drawLine(start, end);
            } else if (m_tool == "rectangle") {
                painter->drawRect(QRectF(start, end).normalized());
            } else if (m_tool == "ellipse") {
                painter->drawEllipse(QRectF(start, end).normalized());
            }
            painter->setBrush(Qt::NoBrush);
        }
    }

    Q_INVOKABLE void undo()
    {
        if (m_undo.isEmpty())
            return;
        m_redo.append(Snapshot{m_layers, m_active});
        restore(m_undo.takeLast());
        emit historyChanged();
    }

    Q_INVOKABLE void redo()
    {
        if (m_redo.isEmpty())
            return;
        m_undo.append(Snapshot{m_layers, m_active});
        restore(m_redo.takeLast());
        emit historyChanged();
    }

    Q_INVOKABLE void clearCanvas()
    {
        pushUndo();
        for (Layer &layer : m_layers) {
            layer.image.fill(Qt::transparent);
        }
        if (!m_layers.isEmpty())
            m_layers[0].image.fill(Qt::white);
        m_compositeDirty = true;
        setDirty(true);
        emit imageChanged();
        emit layersChanged();
        update();
    }

    Q_INVOKABLE bool save(const QString &path)
    {
        QString target = path;
        if (target.isEmpty()) {
            const QString pictures = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
            QDir().mkpath(pictures);
            target = pictures + "/ElvonOS Paint "
                     + QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss") + ".png";
        }
        if (QFileInfo(target).suffix().isEmpty())
            target += ".png";
        QDir().mkpath(QFileInfo(target).absolutePath());
        if (m_compositeDirty)
            rebuildComposite();
        const QString suffix = QFileInfo(target).suffix().toLower();
        const bool jpeg = suffix == "jpg" || suffix == "jpeg";
        QImage exportImage = m_composite;
        if (jpeg) {
            exportImage = QImage(m_width, m_height, QImage::Format_ARGB32);
            exportImage.fill(Qt::white);
            QPainter painter(&exportImage);
            painter.drawImage(0, 0, m_composite);
            painter.end();
        }
        const bool ok = exportImage.save(target, jpeg ? "JPEG" : "PNG", jpeg ? 92 : -1);
        if (ok) {
            setDirty(false);
            m_savedPath = target;
            emit savedPathChanged();
            emit saved(target);
        }
        return ok;
    }

    Q_INVOKABLE bool load(const QString &path)
    {
        QImage image(path);
        if (image.isNull())
            return false;
        resetDocument(image);
        m_savedPath = path;
        emit savedPathChanged();
        emit loaded(path);
        return true;
    }

    Q_INVOKABLE bool addImageLayer(const QString &path)
    {
        QImage image(path);
        if (image.isNull())
            return false;
        pushUndo();
        Layer layer;
        layer.name = "Image";
        layer.image = QImage(m_width, m_height, QImage::Format_ARGB32);
        layer.image.fill(Qt::transparent);
        const QImage scaled = image.scaled(m_width, m_height, Qt::KeepAspectRatio,
                                           Qt::SmoothTransformation);
        QPainter painter(&layer.image);
        painter.drawImage((m_width - scaled.width()) / 2,
                          (m_height - scaled.height()) / 2, scaled);
        painter.end();
        m_layers.append(layer);
        m_active = m_layers.size() - 1;
        m_compositeDirty = true;
        setDirty(true);
        emit layersChanged();
        emit imageChanged();
        update();
        return true;
    }

    Q_INVOKABLE void addLayer()
    {
        pushUndo();
        Layer layer;
        layer.name = "Layer " + QString::number(m_layers.size() + 1);
        layer.image = QImage(m_width, m_height, QImage::Format_ARGB32);
        layer.image.fill(Qt::transparent);
        m_layers.append(layer);
        m_active = m_layers.size() - 1;
        m_compositeDirty = true;
        setDirty(true);
        emit layersChanged();
        update();
    }

    Q_INVOKABLE void duplicateLayer()
    {
        if (m_active < 0 || m_active >= m_layers.size())
            return;
        pushUndo();
        Layer copy = m_layers.at(m_active);
        copy.name = copy.name + " copy";
        m_layers.insert(m_active + 1, copy);
        m_active = m_active + 1;
        m_compositeDirty = true;
        setDirty(true);
        emit layersChanged();
        update();
    }

    Q_INVOKABLE void removeLayer()
    {
        if (m_layers.size() <= 1 || m_active < 0)
            return;
        pushUndo();
        m_layers.removeAt(m_active);
        m_active = std::min<int>(m_active, int(m_layers.size()) - 1);
        m_compositeDirty = true;
        setDirty(true);
        emit layersChanged();
        update();
    }

    Q_INVOKABLE void moveLayerUp()
    {
        if (m_active < 0 || m_active >= m_layers.size() - 1)
            return;
        pushUndo();
        m_layers.swapItemsAt(m_active, m_active + 1);
        m_active = m_active + 1;
        m_compositeDirty = true;
        setDirty(true);
        emit layersChanged();
        update();
    }

    Q_INVOKABLE void moveLayerDown()
    {
        if (m_active <= 0)
            return;
        pushUndo();
        m_layers.swapItemsAt(m_active, m_active - 1);
        m_active = m_active - 1;
        m_compositeDirty = true;
        setDirty(true);
        emit layersChanged();
        update();
    }

    Q_INVOKABLE void setActiveLayer(int index)
    {
        if (index < 0 || index >= m_layers.size() || index == m_active)
            return;
        m_active = index;
        emit layersChanged();
    }

    Q_INVOKABLE void toggleLayerVisible(int index)
    {
        if (index < 0 || index >= m_layers.size())
            return;
        m_layers[index].visible = !m_layers[index].visible;
        m_compositeDirty = true;
        setDirty(true);
        emit layersChanged();
        update();
    }

signals:
    void toolChanged();
    void colorChanged();
    void backgroundColorChanged();
    void brushSizeChanged();
    void shapeFillChanged();
    void historyChanged();
    void dirtyChanged();
    void imageChanged();
    void cursorChanged();
    void savedPathChanged();
    void layersChanged();
    void viewChanged();
    void textRequested(int x, int y);
    void saved(const QString &path);
    void loaded(const QString &path);

protected:
    void mousePressEvent(QMouseEvent *event) override
    {
        if (event->button() == Qt::MiddleButton) {
            m_panning = true;
            m_panLast = event->position();
            setCursor(QCursor(Qt::ClosedHandCursor));
            event->accept();
            return;
        }
        if (event->button() != Qt::LeftButton || imageTargetRect().isEmpty())
            return;
        if (m_active < 0 || m_active >= m_layers.size())
            return;
        const QPointF point = toImage(event->position());
        if (point.x() < 0 || point.y() < 0)
            return;
        m_start = point;
        m_end = point;
        m_last = point;
        m_drawing = true;
        updateCursor(point);

        if (m_tool == "eyedropper") {
            if (m_compositeDirty)
                rebuildComposite();
            const QPoint pixel(point.toPoint());
            if (m_composite.rect().contains(pixel)) {
                const QColor picked = m_composite.pixelColor(pixel);
                if (picked.alpha() > 0)
                    setColor(picked);
            }
            m_drawing = false;
            event->accept();
            return;
        }

        if (m_tool == "text") {
            m_textPoint = point;
            emit textRequested(int(point.x()), int(point.y()));
            m_drawing = false;
            event->accept();
            return;
        }

        if (!m_layers.at(m_active).visible) {
            m_drawing = false;
            event->accept();
            return;
        }

        if (m_tool == "fill") {
            pushUndo();
            floodFill(point.toPoint(), m_color);
            m_drawing = false;
            finishEdit();
            event->accept();
            return;
        }

        pushUndo();
        if (m_tool == "brush" || m_tool == "eraser") {
            drawSegment(point, point);
            m_previewActive = false;
        } else {
            m_previewActive = true;
        }
        update();
        event->accept();
    }

    void mouseMoveEvent(QMouseEvent *event) override
    {
        if (m_panning) {
            m_offset += event->position() - m_panLast;
            m_panLast = event->position();
            update();
            event->accept();
            return;
        }
        const QPointF point = toImage(event->position());
        updateCursor(point);
        if (!m_drawing || point.x() < 0 || point.y() < 0)
            return;
        m_end = point;
        if (m_tool == "brush" || m_tool == "eraser") {
            drawSegment(m_last, point);
            m_last = point;
        }
        update();
        event->accept();
    }

    void mouseReleaseEvent(QMouseEvent *event) override
    {
        if (event->button() == Qt::MiddleButton) {
            m_panning = false;
            setCursor(QCursor(Qt::CrossCursor));
            event->accept();
            return;
        }
        if (!m_drawing)
            return;
        m_drawing = false;
        if (m_tool == "line" || m_tool == "rectangle" || m_tool == "ellipse") {
            QPainter painter(&m_layers[m_active].image);
            painter.setRenderHint(QPainter::Antialiasing, true);
            QPen pen(m_color);
            pen.setWidthF(m_brushSize);
            pen.setCapStyle(Qt::RoundCap);
            pen.setJoinStyle(Qt::RoundJoin);
            painter.setPen(pen);
            painter.setBrush(m_shapeFill && m_tool != "line" ? QBrush(m_color) : QBrush(Qt::NoBrush));
            const QRectF rect(m_start, m_end);
            if (m_tool == "line")
                painter.drawLine(m_start, m_end);
            else if (m_tool == "rectangle")
                painter.drawRect(rect.normalized());
            else
                painter.drawEllipse(rect.normalized());
            painter.end();
            finishEdit();
        }
        m_previewActive = false;
        update();
        event->accept();
    }

    void hoverMoveEvent(QHoverEvent *event) override
    {
        updateCursor(toImage(event->position()));
        QQuickPaintedItem::hoverMoveEvent(event);
    }

    void wheelEvent(QWheelEvent *event) override
    {
        if (imageTargetRect().isEmpty()) {
            event->ignore();
            return;
        }
        const QPointF before = toImage(event->position());
        const qreal factor = std::pow(1.15, event->angleDelta().y() / 120.0);
        setViewZoom(m_viewZoom * factor);
        if (before.x() >= 0)
            m_offset += event->position() - imageToItem(before);
        update();
        event->accept();
    }

private:
    void resetDocument(const QImage &source = QImage())
    {
        m_width = 1280;
        m_height = 800;
        m_layers.clear();
        m_undo.clear();
        m_redo.clear();
        m_active = 0;
        m_previewActive = false;
        m_drawing = false;

        Layer background;
        background.name = "Background";
        background.image = QImage(m_width, m_height, QImage::Format_ARGB32);
        if (source.isNull()) {
            background.image.fill(Qt::white);
        } else {
            background.image.fill(Qt::transparent);
            const QImage scaled = source.scaled(m_width, m_height, Qt::KeepAspectRatio,
                                                Qt::SmoothTransformation);
            QPainter painter(&background.image);
            painter.drawImage((m_width - scaled.width()) / 2,
                              (m_height - scaled.height()) / 2, scaled);
        }
        m_layers.append(background);

        Layer layer;
        layer.name = "Layer 1";
        layer.image = QImage(m_width, m_height, QImage::Format_ARGB32);
        layer.image.fill(Qt::transparent);
        m_layers.append(layer);
        m_active = 1;

        m_viewZoom = 1.0;
        m_offset = QPointF();
        m_compositeDirty = true;
        setDirty(false);
        emit imageChanged();
        emit layersChanged();
        emit historyChanged();
        emit viewChanged();
        update();
    }

    void restore(const Snapshot &snapshot)
    {
        m_layers = snapshot.layers;
        m_active = snapshot.active;
        m_compositeDirty = true;
        setDirty(true);
        emit layersChanged();
        emit imageChanged();
        update();
    }

    QRectF imageTargetRect() const
    {
        if (m_width <= 0 || m_height <= 0 || width() <= 0 || height() <= 0)
            return {};
        const qreal scale = std::min(width() / qreal(m_width), height() / qreal(m_height))
                            * m_viewZoom;
        const QSizeF targetSize(m_width * scale, m_height * scale);
        return QRectF((width() - targetSize.width()) / 2.0 + m_offset.x(),
                      (height() - targetSize.height()) / 2.0 + m_offset.y(),
                      targetSize.width(), targetSize.height());
    }

    QPointF toImage(const QPointF &itemPoint) const
    {
        const QRectF target = imageTargetRect();
        if (target.isEmpty() || !target.contains(itemPoint))
            return QPointF(-1, -1);
        const qreal scaleX = m_width / target.width();
        const qreal scaleY = m_height / target.height();
        const qreal x = qBound<qreal>(0, (itemPoint.x() - target.x()) * scaleX, m_width - 1);
        const qreal y = qBound<qreal>(0, (itemPoint.y() - target.y()) * scaleY, m_height - 1);
        return QPointF(x, y);
    }

    QPointF imageToItem(const QPointF &imagePoint) const
    {
        const QRectF target = imageTargetRect();
        const qreal scaleX = target.width() / std::max(1, m_width);
        const qreal scaleY = target.height() / std::max(1, m_height);
        return QPointF(target.x() + imagePoint.x() * scaleX,
                       target.y() + imagePoint.y() * scaleY);
    }

    void updateCursor(const QPointF &point)
    {
        if (point.x() < 0 || point.y() < 0)
            return;
        const int x = int(point.x());
        const int y = int(point.y());
        if (x == m_cursorX && y == m_cursorY)
            return;
        m_cursorX = x;
        m_cursorY = y;
        emit cursorChanged();
    }

    void drawSegment(const QPointF &from, const QPointF &to)
    {
        QPainter painter(&m_layers[m_active].image);
        painter.setRenderHint(QPainter::Antialiasing, true);
        if (m_tool == "eraser") {
            painter.setCompositionMode(QPainter::CompositionMode_Clear);
        }
        QPen pen(m_color);
        pen.setWidthF(m_brushSize);
        pen.setCapStyle(Qt::RoundCap);
        pen.setJoinStyle(Qt::RoundJoin);
        painter.setPen(pen);
        painter.drawLine(from, to);
        painter.end();
        finishEdit();
    }

    void finishEdit()
    {
        m_compositeDirty = true;
        setDirty(true);
        emit imageChanged();
        update();
    }

    void pushUndo()
    {
        m_undo.append(Snapshot{m_layers, m_active});
        if (m_undo.size() > 16)
            m_undo.removeFirst();
        m_redo.clear();
        emit historyChanged();
    }

    void setDirty(bool value)
    {
        if (m_dirty == value)
            return;
        m_dirty = value;
        emit dirtyChanged();
    }

    void rebuildComposite()
    {
        m_composite = QImage(m_width, m_height, QImage::Format_ARGB32);
        m_composite.fill(Qt::transparent);
        QPainter painter(&m_composite);
        painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
        for (const Layer &layer : m_layers) {
            if (!layer.visible || layer.opacity <= 0.0)
                continue;
            painter.setOpacity(layer.opacity);
            painter.drawImage(0, 0, layer.image);
        }
        painter.end();
        m_compositeDirty = false;
    }

    void floodFill(const QPoint &seed, const QColor &color)
    {
        QImage &image = m_layers[m_active].image;
        if (!image.rect().contains(seed))
            return;
        const QRgb target = image.pixel(seed);
        const QRgb replacement = color.rgba();
        if (colorMatches(target, replacement) && qAlpha(target) == qAlpha(replacement))
            return;

        QVector<QPoint> stack;
        stack.append(seed);
        while (!stack.isEmpty()) {
            const QPoint point = stack.takeLast();
            const int y = point.y();
            if (y < 0 || y >= image.height())
                continue;
            QRgb *line = reinterpret_cast<QRgb *>(image.scanLine(y));
            int left = point.x();
            int right = point.x();
            while (left > 0 && colorMatches(line[left - 1], target))
                --left;
            while (right < image.width() - 1 && colorMatches(line[right + 1], target))
                ++right;
            for (int x = left; x <= right; ++x) {
                if (colorMatches(line[x], target))
                    line[x] = replacement;
            }
            for (int ny : {y - 1, y + 1}) {
                if (ny < 0 || ny >= image.height())
                    continue;
                QRgb *neighbor = reinterpret_cast<QRgb *>(image.scanLine(ny));
                bool span = false;
                for (int x = left; x <= right; ++x) {
                    if (colorMatches(neighbor[x], target)) {
                        if (!span) {
                            stack.append(QPoint(x, ny));
                            span = true;
                        }
                    } else {
                        span = false;
                    }
                }
            }
        }
    }

    QList<Layer> m_layers;
    QList<Snapshot> m_undo;
    QList<Snapshot> m_redo;
    QImage m_composite;
    bool m_compositeDirty = true;
    QString m_tool = "brush";
    QColor m_color = QColor("#1B1B22");
    QColor m_backgroundColor = QColor("#1A1A22");
    int m_brushSize = 6;
    bool m_shapeFill = false;
    bool m_dirty = false;
    bool m_drawing = false;
    bool m_previewActive = false;
    int m_width = 1280;
    int m_height = 800;
    int m_active = 0;
    int m_cursorX = 0;
    int m_cursorY = 0;
    QString m_savedPath;
    QPointF m_start;
    QPointF m_end;
    QPointF m_last;
    QPointF m_offset;
    qreal m_viewZoom = 1.0;
    bool m_panning = false;
    QPointF m_panLast;
    QPointF m_textPoint = QPointF(-1, -1);
};

class PaintApi : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString picturesPath READ picturesPath CONSTANT)

public:
    using QObject::QObject;

    QString picturesPath() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    }

    Q_INVOKABLE QStringList pictures() const
    {
        QDir dir(picturesPath());
        const QFileInfoList files = dir.entryInfoList(
            {"*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"},
            QDir::Files | QDir::Readable, QDir::Time);
        QStringList paths;
        for (const QFileInfo &file : files)
            paths.append(file.absoluteFilePath());
        return paths;
    }

    Q_INVOKABLE QString suggestedName() const
    {
        return "ElvonOS Paint " + QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss");
    }

    Q_INVOKABLE void quit() { QCoreApplication::quit(); }
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-paint"));
    app.setApplicationDisplayName(QStringLiteral("Paint"));
    app.setDesktopFileName(QStringLiteral("elvonos-paint"));

    PaintApi api;
    qmlRegisterType<PaintCanvas>("ElvonOS.Paint", 1, 0, "PaintCanvas");

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty("paintApi", &api);

    engine.load(QUrl("qrc:/Paint.qml"));
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}

#include "main.moc"
