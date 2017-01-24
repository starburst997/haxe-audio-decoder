package;

import openfl.display.Sprite;

/**
 * Test the OGG Decoding ability in OpenFL
 */
class MainOpenFL extends Sprite
{
  var stats:Stats = new Stats();
  var test:TestOGG;

  // Run some tests
	public function new()
  {
		super();

    // Stats
    addChild(stats);

    // Test
		test = new TestOGG();
	}
}