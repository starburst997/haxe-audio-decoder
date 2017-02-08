package;

import openfl.display.Sprite;

/**
 * Test the WAV Decoding ability in OpenFL
 */
class MainOpenFL extends Sprite
{
  var test:TestWAV;

  // Run some tests
	public function new()
  {
		super();

    // Test
		test = new TestWAV();
	}
}