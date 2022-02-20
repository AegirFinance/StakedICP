import { Principal } from "@dfinity/principal";
import { sha224 } from "@dfinity/principal/lib/cjs/utils/sha224";
import { Buffer } from "buffer";
import crc from "crc";

export function arrayOfNumberToUint8Array(numbers: Array<number>): Uint8Array {
  return new Uint8Array(numbers);
}

export function uint8ArrayToArrayBuffer(b: Uint8Array): ArrayBuffer {
  return bufferToArrayBuffer(Buffer.from(b));
}

export function bufferToArrayBuffer(buffer: Buffer): ArrayBuffer {
  return buffer.buffer.slice(
    buffer.byteOffset,
    buffer.byteOffset + buffer.byteLength
  );
}

export function asciiStringToByteArray (text: string): Array<number> {
    return Array
        .from(text)
        .map(c => c.charCodeAt(0));
}

export function principalToAccountIdentifier(principal: Principal, subAccount?: Uint8Array | null): string {
    // Hash (sha224) the principal, the subAccount and some padding
    const padding = asciiStringToByteArray("\x0Aaccount-id");
    const hash = sha224(new Uint8Array([
      ...padding,
      ...principal.toUint8Array(),
      ...(subAccount ?? Array(32).fill(0))
    ]));

    // Prepend the checksum of the hash and convert to a hex string
    const checksum = calculateCrc32(Buffer.from(hash));
    const array2 = new Uint8Array([
        ...checksum,
        ...hash
    ]);
    return Buffer.from(array2).toString("hex");
}

// 4 bytes
function calculateCrc32(bytes: Buffer) : Uint8Array {
    const checksumArrayBuf = new ArrayBuffer(4);
    const view = new DataView(checksumArrayBuf);
    view.setUint32(0, crc.crc32(bytes), false);
    return Buffer.from(checksumArrayBuf);
}
