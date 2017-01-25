package;

import multiloader.MultiLoader;
import sound.decoder.ogg.OggDecoder;
import trace.TraceTimer;

// Tests
enum Tests
{
  DebugChunk;
  DebugSample;
  DebugWAV;
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
      case DebugChunk: debugChunk();
      case DebugSample: debugSample();
      case DebugWAV: debugWAV();
    }
  }
  
  // Simply load a URL and do nothing else
  function debugChunk()
  {
    MultiLoader.loadBytes(
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
    MultiLoader.loadBytes(
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
        for ( i in 0...n )
        {
          str = "";
          for ( j in 0...ogg.channels )
          {
            str += (j == 0 ? "" : " / ") + ogg.getSample(i, j);
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
    MultiLoader.loadBytes(
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
        var end = ogg.length;
        ogg.decode(start, end);
        
        trace('Read ${end - start} samples:');
        
        // Save WAV
        
      },
      error: function(error)
      {
        trace("Error", error);
      }
    });
  }
}