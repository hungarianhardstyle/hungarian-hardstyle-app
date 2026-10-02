package hu.hungarianhardstyle.app

import java.net.HttpURLConnection
import java.net.URL

/**
 * A rádió **„most szól"** metaadata (ICY/Shoutcast) — **natív** olvasó.
 *
 * MIÉRT NATÍV (mérés, 2026-10-01): a rádió előtér-szolgáltatásként szól, tehát
 * akkor is, amikor az app a háttérben van (vagy a felület már nem fut). Az
 * értesítésnek és a zárképernyőnek ilyenkor is a **szóló számot** kell mutatnia,
 * ezért a szolgáltatás saját maga olvassa a metaadatot — nem függ a Dart-oldaltól.
 *
 * ⚠️ A mérés pontosan ezt adta (`https://stream.realhardstyle.nl`):
 *   `icy-name: Real Hardstyle Radio`, `icy-metaint: 16384`, és a 16384. bájt után:
 *   `StreamTitle='LNY TNZ & Nyanda - Light Up Your Life';StreamNext='Rogue Zero - Walk Away';`
 *
 * ⚠️ A Dart-oldali párja (`lib/services/radio_metadata.dart`) ugyanezt a szabályt
 * követi a **felületen** (a sávban) — a kettő szándékos: a natív oldal a
 * háttérben is friss, a Dart-oldal pedig a felületen azonnal.
 */
object RadioMetadataReader {
    const val STREAM_URL = "https://stream.realhardstyle.nl"

    /** Egy kimondott szám: a most szóló és (ha a szerver küldi) a következő. */
    data class Track(val title: String, val next: String) {
        val isEmpty: Boolean get() = title.isBlank()
    }

    /**
     * A stream első metaadat-blokkja.
     *
     * ⚠️ Csak a szükséges bájtokat olvassuk (a hangot eldobjuk), és a kapcsolatot
     * azonnal lezárjuk — a stream végtelen, ezért a naiv olvasás soha nem érne véget.
     * Hálózati hiba vagy hiányzó fejléc esetén `null` (a hívó megtartja a régit).
     */
    fun fetch(url: String = STREAM_URL, timeoutMs: Int = 6000): Track? {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = timeoutMs
                readTimeout = timeoutMs
                setRequestProperty("Icy-MetaData", "1")
                setRequestProperty("User-Agent", "HUHS-App/1.0 (now-playing)")
            }
            connection.connect()
            val metaint = connection.getHeaderField("icy-metaint")?.trim()?.toIntOrNull() ?: return null
            if (metaint <= 0) return null

            val input = connection.inputStream
            val header = ByteArray(metaint + 1)
            var read = 0
            while (read < header.size) {
                val step = input.read(header, read, header.size - read)
                if (step <= 0) break
                read += step
            }
            if (read <= metaint) return null

            val length = (header[metaint].toInt() and 0xFF) * 16
            if (length <= 0) return Track("", "")
            val block = ByteArray(length)
            var blockRead = 0
            while (blockRead < length) {
                val step = input.read(block, blockRead, length - blockRead)
                if (step <= 0) break
                blockRead += step
            }
            runCatching { input.close() }

            val text = String(block, 0, blockRead, Charsets.UTF_8).replace("\u0000", "")
            Track(extract(text, "StreamTitle"), extract(text, "StreamNext"))
        } catch (_: Exception) {
            null
        } finally {
            runCatching { connection?.disconnect() }
        }
    }

    /** A `Key='érték'` alak kiolvasása a metaadat-szövegből (külön, hogy mérhető legyen). */
    fun extract(block: String, key: String): String {
        val match = Regex("$key='([^']*)'").find(block) ?: return ""
        return match.groupValues[1].trim()
    }
}
