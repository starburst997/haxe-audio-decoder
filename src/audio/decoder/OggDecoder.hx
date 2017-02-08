package audio.decoder;

import haxe.io.Bytes;

import stb.format.vorbis.Reader;

/**
 * Simple interface to stb_ogg_sound
 *
 * Progressively decode the OGG by requesting range
 *
 * https://github.com/motion-twin/haxe_stb_ogg_sound (Motion Twin fork)
 */
class OggDecoder extends Decoder
{
  // Max samples read per call
  // Why, i'm not quite sure but this is how it was done in the official
  // library so there must be a good reason...
  private static inline var MAX_SAMPLE = 65536;

  // Stb OGG
  var reader:Reader;

  // Constructor
  public function new( bytes:Bytes )
  {
    trace("");
    reader = Reader.openFromBytes(bytes);
    trace("OGG Reader finished");

    super( reader.totalSample, reader.header.channel, reader.header.sampleRate );
  }

  // Read samples inside the OGG
  private override function read(start:Int, end:Int)
  {
    trace("");

    // Start
    reader.currentSample = start;
    //output.setPosition( start * Decoder.BPS * channels );
    output.setPosition( start * channels );
    
    // Read into output
    var l = end - start;
    while ( l > 0 )
    {
      var n = reader.read(output, l > MAX_SAMPLE ? MAX_SAMPLE : l, channels, sampleRate, Decoder.USE_FLOAT);
      if (n == 0) { break; }
      l -= MAX_SAMPLE;
    }

    //var n = reader.read(output, end - start, channels, sampleRate, USE_FLOAT);
    output.done();

    // Debug
    trace("Read", start, end);
  }
}