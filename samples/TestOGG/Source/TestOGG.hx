package;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import multiloader.MultiLoader;

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
    trace("TestOGG Launch");

    var test = LoadURL1;

    switch(test)
    {
      case LoadURL1: loadURL1();
    }
  }
  
  // Enhance trace() with timing information
  static inline function traceTimer()
  {
    var timer:Float = 0;
    var oldTrace = haxe.Log.trace; // store old function
    haxe.Log.trace = function(v, infos) 
    {
      
      
      oldTrace(v, infos);
    };
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
        ogg = new OggDecoder( bytes, raw );
        
        trace("");
        
        // Read X samples
        //ogg.readSamples(0, 4000);
      },
      error: function(error)
      {
        trace("Error", error);
      }
    });
  }
}