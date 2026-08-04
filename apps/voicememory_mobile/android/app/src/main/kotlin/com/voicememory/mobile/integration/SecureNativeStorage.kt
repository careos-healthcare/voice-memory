package com.voicememory.mobile.integration

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.nio.channels.FileChannel
import java.nio.file.StandardOpenOption
import java.security.KeyStore
import java.security.SecureRandom
import java.util.concurrent.locks.ReentrantLock
import javax.crypto.Cipher
import javax.crypto.CipherInputStream
import javax.crypto.CipherOutputStream
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import kotlin.concurrent.withLock

internal object SecureNativeStorage {
    private const val KEY_ALIAS = "archive_me_android_os_integration_v1"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private val magic = byteArrayOf(0x41, 0x4d, 0x45, 0x31)
    private val processLock = ReentrantLock()

    fun <T> locked(context: Context, block: () -> T): T = processLock.withLock {
        val root = File(context.noBackupFilesDir, "native_os").apply { mkdirs() }
        val lockFile = File(root, ".lock")
        FileChannel.open(
            lockFile.toPath(),
            StandardOpenOption.CREATE,
            StandardOpenOption.WRITE,
        ).use { channel ->
            channel.lock().use { block() }
        }
    }

    fun writeEncryptedAtomic(
        destination: File,
        aad: String,
        writePlaintext: (OutputStream) -> Unit,
    ) {
        destination.parentFile?.mkdirs()
        val temporary = File(destination.parentFile, "${destination.name}.tmp")
        try {
            temporary.outputStream().buffered().use { output ->
                encryptingStream(output, aad).use(writePlaintext)
            }
            check(temporary.renameTo(destination)) { "Unable to commit encrypted file" }
        } finally {
            temporary.delete()
        }
    }

    fun readEncrypted(file: File, aad: String): InputStream {
        val input = file.inputStream().buffered()
        try {
            val header = ByteArray(magic.size)
            require(input.readFully(header) && header.contentEquals(magic)) {
                "Invalid encrypted file"
            }
            val ivLength = input.read()
            require(ivLength in 12..16) { "Invalid encrypted file IV" }
            val iv = ByteArray(ivLength)
            require(input.readFully(iv)) { "Truncated encrypted file" }
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), javax.crypto.spec.GCMParameterSpec(128, iv))
            cipher.updateAAD(aad.toByteArray(Charsets.UTF_8))
            return CipherInputStream(input, cipher)
        } catch (error: Throwable) {
            input.close()
            throw error
        }
    }

    private fun encryptingStream(output: OutputStream, aad: String): OutputStream {
        val iv = ByteArray(12).also(SecureRandom()::nextBytes)
        output.write(magic)
        output.write(iv.size)
        output.write(iv)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey(), javax.crypto.spec.GCMParameterSpec(128, iv))
        cipher.updateAAD(aad.toByteArray(Charsets.UTF_8))
        return CipherOutputStream(output, cipher)
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setRandomizedEncryptionRequired(true)
                    .build(),
            )
            generateKey()
        }
    }

    private fun InputStream.readFully(target: ByteArray): Boolean {
        var offset = 0
        while (offset < target.size) {
            val count = read(target, offset, target.size - offset)
            if (count < 0) return false
            offset += count
        }
        return true
    }
}
