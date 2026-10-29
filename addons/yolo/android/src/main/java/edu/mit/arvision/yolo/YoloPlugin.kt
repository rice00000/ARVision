package edu.mit.arvision.yolo

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.os.SystemClock
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONArray
import org.json.JSONObject
import java.nio.FloatBuffer
import java.util.concurrent.Executors

/**
 * YOLO on the headset (ONNX Runtime, CPU). Same reply as tools/cv_server.py:
 * {"detections": [{"label", "confidence", "box": [x0, y0, x1, y1]}], "ms": inference time}
 * with boxes 0..1 from the image's top left. Work runs on one background thread, in call order;
 * each reply comes back as the "detected" signal on Godot's thread.
 */
class YoloPlugin(godot: Godot) : GodotPlugin(godot) {
    private val worker = Executors.newSingleThreadExecutor()
    private val environment = OrtEnvironment.getEnvironment()
    private lateinit var session: OrtSession
    private lateinit var names: List<String>
    private var size = 640
    private val pixels = IntArray(size * size)
    private val input = FloatBuffer.allocate(3 * size * size)

    override fun getPluginName() = "Yolo"

    override fun getPluginSignals() = setOf(SignalInfo("detected", String::class.java))

    /** An Ultralytics YOLO detection model exported to ONNX at 640 px (its metadata carries the class names). */
    @UsedByGodot
    fun open(model: ByteArray) = worker.execute {
        val options = OrtSession.SessionOptions()
        options.addXnnpack(mapOf("intra_op_num_threads" to "$THREADS"))
        options.setIntraOpNumThreads(1)
        session = environment.createSession(model, options)
        names = Regex("'([^']*)'").findAll(session.metadata.customMetadata.getValue("names")).map { it.groupValues[1] }.toList()
    }

    /** Looks at one JPEG; the answer arrives as "detected". */
    @UsedByGodot
    fun detect(jpeg: ByteArray) = worker.execute {
        val reply = look(BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)).toString()
        runOnRenderThread { emitSignal("detected", reply) }
    }

    private fun look(image: Bitmap): JSONObject {
        val start = SystemClock.elapsedRealtime()
        // Letterbox: scale to fit, centre on grey, as Ultralytics does.
        val scale = minOf(size.toFloat() / image.width, size.toFloat() / image.height)
        val width = Math.round(image.width * scale)
        val height = Math.round(image.height * scale)
        val padX = (size - width) / 2
        val padY = (size - height) / 2
        val square = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        Canvas(square).apply {
            drawColor(Color.rgb(114, 114, 114))
            drawBitmap(image, null, Rect(padX, padY, padX + width, padY + height), Paint(Paint.FILTER_BITMAP_FLAG))
        }
        square.getPixels(pixels, 0, size, 0, 0, size, size)
        val area = size * size
        for (i in 0 until area) {
            val pixel = pixels[i]
            input.put(i, (pixel shr 16 and 0xFF) / 255f)
            input.put(area + i, (pixel shr 8 and 0xFF) / 255f)
            input.put(2 * area + i, (pixel and 0xFF) / 255f)
        }
        val boxes = OnnxTensor.createTensor(environment, input, longArrayOf(1, 3, size.toLong(), size.toLong())).use { tensor ->
            session.run(mapOf(session.inputNames.first() to tensor)).use { result ->
                decode((result[0] as OnnxTensor).floatBuffer, scale, padX, padY, image.width, image.height)
            }
        }
        val detections = JSONArray()
        for (box in boxes) {
            detections.put(JSONObject()
                .put("label", names[box.label])
                .put("confidence", box.confidence.toDouble())
                .put("box", JSONArray(box.corners.map { it.toDouble() })))
        }
        return JSONObject().put("detections", detections).put("ms", SystemClock.elapsedRealtime() - start)
    }

    private class Box(val label: Int, val confidence: Float, val corners: FloatArray)

    /** Output (1, 4 + classes, anchors): centre x, centre y, width, height in input pixels, then class scores. */
    private fun decode(output: FloatBuffer, scale: Float, padX: Int, padY: Int, width: Int, height: Int): List<Box> {
        val anchors = output.capacity() / (4 + names.size)
        val candidates = ArrayList<Box>()
        for (a in 0 until anchors) {
            var label = 0
            var best = 0f
            for (c in names.indices) {
                val score = output.get((4 + c) * anchors + a)
                if (score > best) {
                    best = score
                    label = c
                }
            }
            if (best < MIN_CONFIDENCE) continue
            val cx = output.get(a)
            val cy = output.get(anchors + a)
            val w = output.get(2 * anchors + a)
            val h = output.get(3 * anchors + a)
            candidates.add(Box(label, best, floatArrayOf(
                ((cx - w / 2 - padX) / scale / width).coerceIn(0f, 1f),
                ((cy - h / 2 - padY) / scale / height).coerceIn(0f, 1f),
                ((cx + w / 2 - padX) / scale / width).coerceIn(0f, 1f),
                ((cy + h / 2 - padY) / scale / height).coerceIn(0f, 1f))))
        }
        // Non-maximum suppression per class.
        candidates.sortByDescending { it.confidence }
        val kept = ArrayList<Box>()
        for (box in candidates) {
            if (kept.none { it.label == box.label && overlap(it.corners, box.corners) > MAX_OVERLAP }) kept.add(box)
        }
        return kept
    }

    private fun overlap(a: FloatArray, b: FloatArray): Float {
        val inter = maxOf(0f, minOf(a[2], b[2]) - maxOf(a[0], b[0])) * maxOf(0f, minOf(a[3], b[3]) - maxOf(a[1], b[1]))
        return inter / ((a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter)
    }

    companion object {
        const val THREADS = 2
        const val MIN_CONFIDENCE = 0.25f
        const val MAX_OVERLAP = 0.7f
    }
}
