package com.izzzulmakin.ugvmakin

/**
 * Created by kareem on 25/12/18.
 */
class HelperKotlin {
    companion object {
        fun byteArrayOfChars(vararg charracter: Char): ByteArray {
            return ByteArray(charracter.size) { pos -> charracter[pos].toByte() }
        }
    }
}