package;

import file.load.FileLoad;
import file.save.FileSave;
import audio.decoder.OggDecoder;
import haxe.Timer;

import statistics.Stats;
import statistics.TraceTimer;

// Tests
enum Tests
{
  DebugChunk;
  DebugSample;
  DebugWAV;
  DebugHeader;
}

/**
 * Class used to Test OGG Decoder
 *
 * Install https://github.com/tapio/live-server and start from html5 folder
 * Simply issue "live-server" inside the html5 folder and build (release for faster build)
 * Server will reload page automatically when JS is compiled
 */
class TestOGG
{
  // Stats
  var stats:Stats = new Stats();

  // Ogg File
  private var ogg:OggDecoder;

  // List of files
  public static inline var PATH:String = "./assets/";
  public static inline var TEST1:String = PATH + "test1.ogg";

  // Run some tests
  public function new()
  {
    TraceTimer.activate();

    trace("TestOGG Launch");

    var test = DebugWAV;

    switch(test)
    {
      case DebugHeader: debugHeader();
      case DebugChunk: debugChunk();
      case DebugSample: debugSample();
      case DebugWAV: debugWAV();
    }
  }

  // Debug Header
  function debugHeader()
  {
    FileLoad.loadBytes(
    {
      url: TEST1,
      complete: function(bytes)
      {
        trace("Downloading complete");
        
        // Create
        ogg = new OggDecoder( bytes );
        
        trace(ogg.length, ogg.channels, ogg.sampleRate);
      },
      error: function(error)
      {
        trace("Error", error);
      }
    });
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
        ogg = new OggDecoder( bytes );

        // Test Random Read
        trace(ogg.chunkString());

        for ( i in 0...500 )
        {
          var l = Std.int( Math.random() * ogg.length * 0.05 );
          if ( l <= 0 ) l = 1;

          var start = Std.int( Math.random() * (ogg.length - l) );
          var end = start + l;

          ogg.decode(start, end);

          //trace("T: " + ogg.chunkDebug(start, end));
          trace("C: " + ogg.chunkString());
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
        ogg = new OggDecoder( bytes );

        // Read X samples
        trace("");
        var start = 0;
        var end = 200;
        ogg.decode(start, end);

        trace('Read ${end - start} samples:');

        // Trace Bytes
        var str = "";
        var n = (end - start) + 10; // Add some padding, should be 0

        ogg.startSample(0);
        for ( i in 0...n )
        {
          str = "";
          for ( j in 0...ogg.channels )
          {
            //str += (j == 0 ? "" : " / ") + ogg.getSample(i, j);
            str += (j == 0 ? "" : " / ") + ogg.nextSample();
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
      url: TEST1,
      complete: function(bytes)
      {
        trace("Downloading complete");

        // Create
        ogg = new OggDecoder( bytes );

        // Read X samples
        trace("");
        
        ogg.decodeAll(function()
        {
          trace('Read ${ogg.length} samples');

          // Save WAV
          var wav = ogg.getWAV();
          trace('Wav Decoded');

          FileSave.saveClickBytes(wav, 'test.wav', 'audio/wav');
        });
        
        /*var timer = new Timer(2000);
        timer.run = function()
        {
          timer.stop();
          
          trace("START");
          
          // Maybe file is slow...
          ogg.decodeAll(function()
          {
            trace('Read ${ogg.length} samples');

            // Save WAV
            var wav = ogg.getWAV();
            trace('Wav Decoded');

            FileSave.saveClickBytes(wav, 'test.wav', 'audio/wav');
          });
        };*/
      },
      error: function(error)
      {
        trace("Error", error);
      }
    });
  }
}