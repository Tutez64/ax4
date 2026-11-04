/**
 * ByteArraySubclassLength: a ByteArray subclass converts to an ASByteArrayBase, whose own length
 * cannot be written, so setting length goes through the ByteArray abstract:
 * `(packet : ByteArray).length = 0`, also for a compound assignment and through a subclass of the
 * subclass. Reading length and setting it on a plain ByteArray are left alone.
 */
package {
    import flash.utils.ByteArray;

    public class TestFilterByteArraySubclassLength {
        public function reset(packet:TestFilterByteArraySubclassLengthPacket, raw:ByteArray):uint {
            packet.length = 0;
            packet.length += 4;
            new TestFilterByteArraySubclassLengthSmall().length = 2;
            raw.length = 1;
            return packet.length;
        }
    }
}

import flash.utils.ByteArray;

class TestFilterByteArraySubclassLengthPacket extends ByteArray {
}

class TestFilterByteArraySubclassLengthSmall extends TestFilterByteArraySubclassLengthPacket {
}
