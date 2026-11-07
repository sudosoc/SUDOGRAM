package com.sudosoc.sudogram

import android.media.MediaCodec
import android.media.MediaFormat
import java.io.ByteArrayOutputStream
import java.io.File

/** Encodes a 48 kHz mono 16-bit WAV (44-byte header) to OGG/Opus via MediaCodec (API 29+). */
object OpusOgg {
    private const val RATE = 48000
    private val crcTable = IntArray(256).also { t ->
        for (i in 0 until 256) {
            var r = i shl 24
            for (j in 0 until 8) r = if (r and 0x80000000.toInt() != 0) (r shl 1) xor 0x04C11DB7 else r shl 1
            t[i] = r
        }
    }

    private fun crc(b: ByteArray): Int {
        var c = 0
        for (x in b) c = (c shl 8) xor crcTable[((c ushr 24) and 0xFF) xor (x.toInt() and 0xFF)]
        return c
    }

    fun encode(wav: String, out: String) {
        if (android.os.Build.VERSION.SDK_INT < 29) throw Exception("opus encoder needs Android 10+")
        val raw = File(wav).readBytes()
        val pcm = raw.copyOfRange(44, raw.size)
        val fmt = MediaFormat.createAudioFormat("audio/opus", RATE, 1)
        fmt.setInteger(MediaFormat.KEY_BIT_RATE, 32000)
        val codec = MediaCodec.createEncoderByType("audio/opus")
        codec.configure(fmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        val info = MediaCodec.BufferInfo()
        val packets = ArrayList<ByteArray>()
        var head: ByteArray? = null
        var inPos = 0
        var pts = 0L
        var inDone = false
        var outDone = false
        try {
            while (!outDone) {
                if (!inDone) {
                    val i = codec.dequeueInputBuffer(10000)
                    if (i >= 0) {
                        val b = codec.getInputBuffer(i)!!
                        b.clear()
                        val n = minOf(b.remaining() and 1.inv(), pcm.size - inPos)
                        if (n <= 0) {
                            codec.queueInputBuffer(i, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inDone = true
                        } else {
                            b.put(pcm, inPos, n)
                            codec.queueInputBuffer(i, 0, n, pts, 0)
                            pts += (n / 2) * 1_000_000L / RATE
                            inPos += n
                        }
                    }
                }
                val o = codec.dequeueOutputBuffer(info, 10000)
                if (o >= 0) {
                    val ob = codec.getOutputBuffer(o)!!
                    val bytes = ByteArray(info.size)
                    ob.position(info.offset)
                    ob.get(bytes)
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        if (bytes.size >= 19 && String(bytes, 0, 8) == "OpusHead") head = bytes
                    } else if (info.size > 0) {
                        packets.add(bytes)
                    }
                    codec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outDone = true
                }
            }
        } finally {
            codec.stop()
            codec.release()
        }
        if (packets.isEmpty()) throw Exception("no opus output")
        val opusHead = head ?: ByteArray(19).also {
            "OpusHead".toByteArray().copyInto(it)
            it[8] = 1; it[9] = 1
            it[10] = (312 and 0xFF).toByte(); it[11] = (312 shr 8).toByte()
            it[12] = (RATE and 0xFF).toByte(); it[13] = ((RATE shr 8) and 0xFF).toByte()
            it[14] = ((RATE shr 16) and 0xFF).toByte()
        }
        writeOgg(out, opusHead, packets)
    }

    /** Samples (48 kHz) in one Opus packet, from its TOC byte. */
    private fun packetSamples(p: ByteArray): Long {
        val toc = p[0].toInt() and 0xFF
        val cfg = toc shr 3
        val frame = when {
            cfg < 12 -> longArrayOf(480, 960, 1920, 2880)[cfg % 4]
            cfg < 16 -> longArrayOf(480, 960)[cfg % 2]
            else -> longArrayOf(120, 240, 480, 960)[cfg % 4]
        }
        val count = when (toc and 3) {
            0 -> 1
            1, 2 -> 2
            else -> if (p.size > 1) p[1].toInt() and 0x3F else 1
        }
        return frame * count
    }

    private class Page(val serial: Int) {
        var seq = 0
    }

    private fun page(os: ByteArrayOutputStream, pg: Page, type: Int, granule: Long, pkts: List<ByteArray>) {
        val segs = ArrayList<Int>()
        val body = ByteArrayOutputStream()
        for (p in pkts) {
            var n = p.size
            while (n >= 255) { segs.add(255); n -= 255 }
            segs.add(n)
            body.write(p)
        }
        val h = ByteArrayOutputStream()
        h.write("OggS".toByteArray())
        h.write(0)
        h.write(type)
        for (i in 0 until 8) h.write(((granule shr (8 * i)) and 0xFF).toInt())
        for (i in 0 until 4) h.write((pg.serial shr (8 * i)) and 0xFF)
        for (i in 0 until 4) h.write((pg.seq shr (8 * i)) and 0xFF)
        h.write(ByteArray(4))
        h.write(segs.size)
        for (s in segs) h.write(s)
        h.write(body.toByteArray())
        val all = h.toByteArray()
        val c = crc(all)
        for (i in 0 until 4) all[22 + i] = ((c shr (8 * i)) and 0xFF).toByte()
        os.write(all)
        pg.seq++
    }

    private fun writeOgg(path: String, head: ByteArray, packets: List<ByteArray>) {
        val os = ByteArrayOutputStream()
        val pg = Page(0x5355444F)
        page(os, pg, 0x02, 0, listOf(head))
        val tags = ByteArrayOutputStream().apply {
            write("OpusTags".toByteArray())
            val v = "SUDOGRAM".toByteArray()
            for (i in 0 until 4) write((v.size shr (8 * i)) and 0xFF)
            write(v)
            write(ByteArray(4))
        }.toByteArray()
        page(os, pg, 0, 0, listOf(tags))
        var granule = 0L
        var batch = ArrayList<ByteArray>()
        var segCount = 0
        for ((idx, p) in packets.withIndex()) {
            val need = p.size / 255 + 1
            if (segCount + need > 250 || batch.size >= 40) {
                page(os, pg, 0, granule, batch)
                batch = ArrayList(); segCount = 0
            }
            batch.add(p)
            segCount += need
            granule += packetSamples(p)
            if (idx == packets.size - 1) {
                page(os, pg, 0x04, granule, batch)
                batch = ArrayList()
            }
        }
        File(path).writeBytes(os.toByteArray())
    }
}
