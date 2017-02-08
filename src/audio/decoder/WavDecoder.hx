package audio.decoder;

import haxe.io.Bytes;
import haxe.io.BytesInput;

enum WAVEFormat {
  WF_PCM;
}

/**
 * Simple interface to decode WAV file
 */
class WavDecoder extends Decoder
{
  var startData:Int = 0;
  var byte:Int = 2;
  var bytes:Bytes = null;
  
  inline function readInt(i) {
		#if haxe3
		return i.readInt32();
		#else
		return i.readUInt30();
		#end
	}
  
  // Constructor
  public function new( bytes:Bytes )
  {
    trace("");
    
    this.bytes = bytes;
    
    // Read WAV Headers (https://github.com/HaxeFoundation/format/blob/master/format/wav/Reader.hx)
    var i = new BytesInput( bytes );
    
    if (i.readString(4) != "RIFF")
			throw "RIFF header expected";

		var len = readInt(i);

		if (i.readString(4) != "WAVE")
			throw "WAVE signature not found";

		var fmt = i.readString(4);
		while(fmt != "fmt ") {
			switch( fmt ) {
				case "JUNK": //protool
					var junkLen = i.readInt32();
					i.read(junkLen);
					fmt = i.readString(4);
				case "bext":
					var bextLen = i.readInt32();
					i.read(bextLen);
					fmt = i.readString(4);
				default: 
					break;
			}
		}
		if ( fmt != "fmt " ) 
			throw "unsupported wave chunk "+fmt;

		var fmtlen = readInt(i);
		var format = switch (i.readUInt16()) {
			case 1,3: WF_PCM;
			default: throw "only PCM (uncompressed) WAV files are supported";
		}
		var channels = i.readUInt16();
		var samplingRate = readInt(i);
		var byteRate = readInt(i);
		var blockAlign = i.readUInt16();
		var bitsPerSample = i.readUInt16();
		
		if (fmtlen > 16) 
			i.read(fmtlen - 16);
		
		var nextChunk = i.readString (4);
		while (nextChunk != "data") {
			// read past other subchunks
			i.read(readInt(i));
			nextChunk = i.readString (4);
		}
		
		// data
		if (nextChunk != "data")
			throw "expected data subchunk";
		
		var datalen = readInt(i);
		
    startData = i.position;
    
    trace("WAV Reader finished");

    byte = Std.int(bitsPerSample / 8);
    
    trace("WAV", Std.int(datalen / channels / byte), datalen, byte, channels, sampleRate);
    
    // Create Decoder
    super( Std.int(datalen / channels / byte), channels, samplingRate );
  }
  
  private inline function sext16(v:Int)
  {
    return (v & 0x8000) == 0 ? v : v | 0xFFFF0000;
  }
  
  // Read samples inside the WAV
  private override function read(start:Int, end:Int)
  {
    trace("");

    // Start
    var position = startData + (start * channels * byte) - byte;
    output.setPosition( start * channels );
    
    // Read into output
    var l = (end - start) * channels;
    
    // Based on bits per sample
    if ( byte == 2 ) // 16 bit
    {
      for ( i in 0...l )
      {
        output.writeFloat( sext16(bytes.getUInt16(position += 2)) / 0x8000 );
      }
    }
    else if ( byte == 1 ) // 8 bit
    {
      for ( i in 0...l )
      {
        output.writeFloat( (bytes.get(++position) - 127) / 128 );
      }
    }
    else if ( byte == 4 ) // 32 bit
    {
      // Test ???
      for ( i in 0...l )
      {
        output.writeFloat( bytes.getFloat(position += 4) );
      }
    }
    else
    {
      // 24 bit ??? 64 bit ???
    }
    
    output.done();

    // Debug
    trace("Read", start, end);
  }
}