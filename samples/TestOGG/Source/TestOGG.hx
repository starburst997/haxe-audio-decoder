package;

import haxe.io.BytesOutput;

import multiloader.MultiLoader;
import sound.decoder.ogg.OggDecoder;
import trace.TraceTimer;

// Tests
enum Tests
{
  LoadURL1;
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
  
  // Decoded Ogg File (16bit Samples / 2 Channels)
  private var raw:BytesOutput;
  
  // List of files
  public static inline var PATH:String = "./assets/";
  public static inline var TEST1:String = PATH + "test1.ogg";

  // Run some tests
  public function new()
  {
    TraceTimer.activate();
    
    trace("TestOGG Launch");

    var test = LoadURL1;

    switch(test)
    {
      case LoadURL1: loadURL1();
    }
  }
  
  // Simply load a URL and do nothing else
  function loadURL1()
  {
    MultiLoader.loadBytes(
    { 
      url: TEST1, 
      complete: function(bytes)
      {
        trace("Downloading complete");
        
        // Create 
        raw = new BytesOutput();
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
        
        trace("");
        
        // Read X samples
        //ogg.readSamples(0, 4000);
        
        trace("Read 4000 samples");
      },
      error: function(error)
      {
        trace("Error", error);
      }
    });
  }
  
  // Simple read
  function loadURL2()
  {
    MultiLoader.loadBytes(
    { 
      url: TEST1, 
      complete: function(bytes)
      {
        trace("Downloading complete");
        
        // Create 
        raw = new BytesOutput();
        ogg = new OggDecoder( bytes );
        
        // Test Random Read
        trace(ogg.chunkString());
        
        
        
        trace("");
        
        // Read X samples
        //ogg.readSamples(0, 4000);
        
        trace("Read 4000 samples");
      },
      error: function(error)
      {
        trace("Error", error);
      }
    });
  }
}