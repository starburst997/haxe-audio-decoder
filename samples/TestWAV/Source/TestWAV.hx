package;

import file.load.FileLoad;
import file.save.FileSave;
import audio.decoder.WavDecoder;

import statistics.Stats;
import statistics.TraceTimer;

// Tests
enum Tests
{
  DebugChunk;
  DebugSample;
  DebugWAV;
}

/**
 * Class used to Test WAV Decoder
 *
 * Install https://github.com/tapio/live-server and start from html5 folder
 * Simply issue "live-server" inside the html5 folder and build (release for faster build)
 * Server will reload page automatically when JS is compiled
 */
class TestWAV
{
  // Stats
  var stats:Stats = new Stats();

  // Wav File
  private var wav:WavDecoder;

  // List of files
  public static inline var PATH:String = "./assets/";
  public static inline var TEST1:String = PATH + "a.wav";
  public static inline var TEST2:String = PATH + "b.wav";
  public static inline var TEST3:String = PATH + "c.wav";
  public static inline var TEST4:String = PATH + "d.wav";
  public static inline var TEST5:String = PATH + "e.wav";
  public static inline var TEST6:String = PATH + "f.wav";

  // Run some tests
  public function new()
  {
    TraceTimer.activate();

    trace("TestWAV Launch");

    var test = DebugWAV;

    switch(test)
    {
      case DebugChunk: debugChunk();
      case DebugSample: debugSample();
      case DebugWAV: debugWAV();
    }
  }

  // Simply load a URL and do nothing else
  function debugChunk()
  {
    FileLoad.loadBytes(
    {
      url: TEST1,
      complete: function(bytes)
      {
        trace("Downloading complete");

        // Create
        wav = new WavDecoder( bytes );

        // Test Random Read
        trace(wav.chunkString());

        for ( i in 0...500 )
        {
          var l = Std.int( Math.random() * wav.length * 0.05 );
          if ( l <= 0 ) l = 1;

          var start = Std.int( Math.random() * (wav.length - l) );
          var end = start + l;

          wav.decode(start, end);

          //trace("T: " + wav.chunkDebug(start, end));
          trace("C: " + wav.chunkString());
        }
      },
      error: function(error)
      {
        trace("Error", error);
      }
    });
  }

  // Simple read
  function debugSample()
  {
    FileLoad.loadBytes(
    {
      url: TEST1,
      complete: function(bytes)
      {
        trace("Downloading complete");

        // Create
        wav = new WavDecoder( bytes );

        // Read X samples
        trace("");
        var start = 0;
        var end = 200;
        wav.decode(start, end);

        trace('Read ${end - start} samples:');

        // Trace Bytes
        var str = "";
        var n = (end - start) + 10; // Add some padding, should be 0

        wav.startSample(0);
        for ( i in 0...n )
        {
          str = "";
          for ( j in 0...wav.channels )
          {
            //str += (j == 0 ? "" : " / ") + wav.getSample(i, j);
            str += (j == 0 ? "" : " / ") + wav.nextSample();
          }

          trace( i, str );
        }
      },
      error: function(error)
      {
        trace("Error", error);
      }
    });
  }

  // Save back to WAV
  function debugWAV()
  {
    FileLoad.loadBytes(
    {
      url: TEST6,
      complete: function(bytes)
      {
        trace("Downloading complete");

        // Create
        wav = new WavDecoder( bytes );

        // Read X samples
        trace("");
        wav.decodeAll(function()
        {
          trace('Read ${wav.length} samples');

          // Save WAV
          var wavDecoded = wav.getWAV();
          trace('Wav Decoded');

          FileSave.saveClickBytes(wavDecoded, 'test.wav', 'audio/wav');
        });
      },
      error: function(error)
      {
        trace("Error", error);
      }
    });
  }
}