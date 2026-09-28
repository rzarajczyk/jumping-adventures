package pl.zarajczyk.jumpingpenguin.lan

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.SystemClock
import android.view.View
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.journeyapps.barcodescanner.BarcodeEncoder
import com.journeyapps.barcodescanner.CaptureActivity
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.io.ByteArrayOutputStream
import java.net.Inet4Address
import java.net.NetworkInterface

class LanCaptureActivity : CaptureActivity()

class JumpingLan(godot: Godot) : GodotPlugin(godot) {
    private var scanner: ActivityResultLauncher<ScanOptions>? = null
    private var permission: ActivityResultLauncher<String>? = null
    private var scanning = false

    override fun getPluginName() = "JumpingLan"

    override fun getPluginSignals() = setOf(
        SignalInfo("scan_completed", String::class.java),
        SignalInfo("scan_failed", String::class.java),
        SignalInfo("scan_canceled")
    )

    override fun onMainCreate(activity: Activity?): View? {
        val host = activity as? ComponentActivity ?: return null
        // Registry registration without a LifecycleOwner also works if Godot
        // initializes the plugin after Activity.onStart. Explicitly unregister.
        scanner = host.activityResultRegistry.register("jumping_lan_scan", ScanContract()) { result ->
            scanning = false
            if (result.contents == null) emitSignal("scan_canceled")
            else emitSignal("scan_completed", result.contents)
        }
        permission = host.activityResultRegistry.register(
            "jumping_lan_camera", ActivityResultContracts.RequestPermission()
        ) { granted ->
            if (granted) launchScanner()
            else {
                scanning = false
                emitSignal("scan_failed", "Zezwól na aparat, aby zeskanować QR. Możesz zmienić zgodę w ustawieniach aplikacji.")
            }
        }
        return null
    }

    @UsedByGodot
    fun elapsedRealtime(): Long = SystemClock.elapsedRealtime()

    @UsedByGodot
    fun scanQr() {
        activity?.runOnUiThread {
            val current = activity ?: return@runOnUiThread
            if (scanning) return@runOnUiThread
            if (scanner == null || !current.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
                emitSignal("scan_failed", "Nie można uruchomić aparatu na tym urządzeniu.")
                return@runOnUiThread
            }
            scanning = true
            if (current.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                launchScanner()
            } else permission?.launch(Manifest.permission.CAMERA)
        }
    }

    private fun launchScanner() {
        try {
            scanner?.launch(ScanOptions()
                .setDesiredBarcodeFormats(ScanOptions.QR_CODE)
                .setCaptureActivity(LanCaptureActivity::class.java)
                .setPrompt("Zeskanuj kod z telefonu gospodarza")
                .setOrientationLocked(false)
                .setBarcodeImageEnabled(false)
                .setBeepEnabled(false))
        } catch (_: Exception) {
            scanning = false
            emitSignal("scan_failed", "Nie można uruchomić aparatu. Zamknij inne aplikacje korzystające z aparatu i spróbuj ponownie.")
        }
    }

    @UsedByGodot
    fun qrPng(payload: String): ByteArray {
        if (payload.length > 2048) return byteArrayOf()
        return try {
            val bitmap = BarcodeEncoder().encodeBitmap(payload, BarcodeFormat.QR_CODE, 512, 512,
                mapOf(EncodeHintType.MARGIN to 4, EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M))
            val bytes = ByteArrayOutputStream().use {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
                it.toByteArray()
            }
            bitmap.recycle()
            bytes
        } catch (_: Exception) { byteArrayOf() }
    }

    @UsedByGodot
    fun localAddresses(): Array<String> {
        val addresses = linkedSetOf<String>()
        try {
            val connectivity = activity?.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            connectivity?.allNetworks?.forEach { network ->
                val caps = connectivity.getNetworkCapabilities(network)
                if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true && !caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                    connectivity.getLinkProperties(network)?.linkAddresses?.forEach { link ->
                        val ip = link.address
                        if (ip is Inet4Address && !ip.isLoopbackAddress) ip.hostAddress?.let(addresses::add)
                    }
                }
            }
            // A hotspot's local interface need not be an Android Network (the
            // default Network often represents its cellular upstream instead).
            NetworkInterface.getNetworkInterfaces()?.toList()?.forEach { network ->
                val name = network.name.lowercase()
                if (network.isUp && !network.isLoopback &&
                    listOf("wlan", "wifi", "ap", "swlan", "eth", "en", "softap").any(name::startsWith)) {
                    network.inetAddresses.toList().filterIsInstance<Inet4Address>()
                        .filter { !it.isLoopbackAddress && it.isSiteLocalAddress }
                        .forEach { it.hostAddress?.let(addresses::add) }
                }
            }
        } catch (_: Exception) { /* GDScript shows an actionable no-network screen. */ }
        return addresses.toTypedArray()
    }

    override fun onMainDestroy() {
        scanner?.unregister()
        permission?.unregister()
        scanner = null
        permission = null
        scanning = false
    }
}
