package;

import openfl.display.Sprite;

/**
 * Test the OGG Decoding ability in OpenFL
 */
class MainOpenFL extends Sprite
{
  var test:TestOGG;

  // Run some tests
	public function new()
  {
		super();

    // Test
		test = new TestOGG();
	}
}