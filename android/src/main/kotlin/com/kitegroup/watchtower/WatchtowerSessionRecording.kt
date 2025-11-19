package com.kitegroup.watchtower

import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.view.Window
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream


class WatchtowerSessionRecording(private val onFrameCaptured: (ByteArray) -> Unit) {

    private val pixelCopyThread = HandlerThread("WatchtowerPixelCopy").apply { start() }
    private val pixelCopyHandler = Handler(pixelCopyThread.looper)
    private val compressionThread = HandlerThread("WatchtowerCompression").apply { start() }
    private val compressionHandler = Handler(compressionThread.looper)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val manualCaptureThread = HandlerThread("WatchtowerManualCapture").apply { start() }
    private val manualCaptureHandler = Handler(manualCaptureThread.looper)

    fun startRecorder(interval: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            while (true) {
                takeScreenshot()
                delay(interval)
            }
        }
    }

    private fun takeScreenshot() {
        val activity = ScreenRec.currentActivity ?: return
        val window = activity.window
        val view = window.decorView.rootView

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val windowWidth = view.width.takeIf { it > 0 } ?: window.decorView.width
            val windowHeight = view.height.takeIf { it > 0 } ?: window.decorView.height

            if (windowWidth <= 0 || windowHeight <= 0) {
                Log.e("WatchtowerSessionRecording", "Window has invalid size: $windowWidth x $windowHeight")
                return
            }

            val surfaceView = getSurfaceView(view)

            if (surfaceView != null && surfaceView.holder.surface.isValid) {
                val surfaceWidth = surfaceView.width.takeIf { it > 0 } ?: windowWidth
                val surfaceHeight = surfaceView.height.takeIf { it > 0 } ?: windowHeight

                captureSurface(surfaceView, surfaceWidth, surfaceHeight) {
                    captureWindow(window, windowWidth, windowHeight)
                }
            } else {
                captureWindow(window, windowWidth, windowHeight)
            }
        } else {
            manualCapture(view)
        }
    }

    private fun getSurfaceView(view: View): SurfaceView? {
        var surfaceView: SurfaceView? = null
        traverseView(view) { v ->
            if (v is SurfaceView) surfaceView = v
        }
        return surfaceView
    }

    private fun traverseView(view: View, callback: (View) -> Unit) {
        callback(view)
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                traverseView(view.getChildAt(i), callback)
            }
        }
    }

    private fun captureSurface(surfaceView: SurfaceView, width: Int, height: Int, fallback: () -> Unit) {
        val scale = width.toFloat() / height.toFloat()
        val resolution = 640
        val scaledHeight = resolution
        val scaledWidth = (resolution * scale).toInt()

        val bitmap = Bitmap.createBitmap(scaledWidth, scaledHeight, Bitmap.Config.ARGB_8888)

        try {
            PixelCopy.request(surfaceView, bitmap, { copyResult ->
                if (copyResult == PixelCopy.SUCCESS) {
                    deliverBitmap(bitmap)
                } else {
                    Log.e("WatchtowerSessionRecording", "PixelCopy surface failed with code $copyResult")
                    bitmap.recycle()
                    fallback()
                }
            }, pixelCopyHandler)
        } catch (e: IllegalArgumentException) {
            Log.e("WatchtowerSessionRecording", "PixelCopy surface threw IllegalArgumentException", e)
            bitmap.recycle()
            fallback()
        }
    }

    private fun captureWindow(window: Window, width: Int, height: Int) {
        val scale = width.toFloat() / height.toFloat()
        val resolution = 640
        val scaledHeight = resolution
        val scaledWidth = (resolution * scale).toInt()

        val bitmap = Bitmap.createBitmap(scaledWidth, scaledHeight, Bitmap.Config.ARGB_8888)

        try {
            PixelCopy.request(window, bitmap, { copyResult ->
                if (copyResult == PixelCopy.SUCCESS) {
                    deliverBitmap(bitmap)
                } else {
                    Log.e("WatchtowerSessionRecording", "PixelCopy window failed with code $copyResult")
                    bitmap.recycle()
                    manualCapture(window.decorView.rootView)
                }
            }, pixelCopyHandler)
        } catch (e: IllegalArgumentException) {
            Log.e("WatchtowerSessionRecording", "PixelCopy window threw IllegalArgumentException", e)
            bitmap.recycle()
            manualCapture(window.decorView.rootView)
        }
    }

    private fun manualCapture(view: View) {
        manualCaptureHandler.post {
            manualCaptureOnMain(view)
        }
    }

    private fun manualCaptureOnMain(view: View) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { manualCaptureOnMain(view) }
            return
        }

        val width = view.width
        val height = view.height
        if (width <= 0 || height <= 0) {
            Log.e("WatchtowerSessionRecording", "manualCapture: invalid size $width x $height")
            return
        }

        val scale = width.toFloat() / height.toFloat()
        val resolution = 640
        val scaledHeight = resolution
        val scaledWidth = (resolution * scale).toInt()

        val bitmap = Bitmap.createBitmap(scaledWidth, scaledHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.scale(scaledWidth.toFloat() / width, scaledHeight.toFloat() / height)
        view.draw(canvas)
        canvas.setBitmap(null)
        deliverBitmap(bitmap)
    }

    private fun deliverBitmap(bitmap: Bitmap) {
        compressionHandler.post {
            val byteArray = bitmapToByteArray(bitmap)
            bitmap.recycle()
            mainHandler.post {
                onFrameCaptured(byteArray)
            }
        }
    }

    private fun bitmapToByteArray(bitmap: Bitmap): ByteArray {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 10, stream)
        return stream.toByteArray()
    }

    fun dispose() {
        pixelCopyThread.quitSafely()
        compressionThread.quitSafely()
        manualCaptureThread.quitSafely()
    }
}
