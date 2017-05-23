using Uno;
using Uno.UX;
using Uno.Testing;

using FuseTest;

namespace Fuse.Reactive.Test
{
	public class MathFunctionsTest : TestBase
	{
		[Test]
		public void Mod()
		{
			var p = new UX.MathFunctions.Mod();
			using (var root = TestRootPanel.CreateWithChild(p))
			{
				Assert.AreEqual(1, p.c.Integer);
				
				p.b.Float = 3.5f;
				root.PumpDeferred();
				Assert.AreEqual(3.0f, p.c.Float);
				
				p.a.Float = -9.5f;
				root.PumpDeferred();
				Assert.AreEqual(1f, p.c.Float);
				
				p.b.Float = -3f;
				root.PumpDeferred();
				Assert.AreEqual(-0.5f, p.c.Float);
			}
		}

		[Test]
		public void EvenOdd()
		{
			var p = new UX.MathFunctions.EvenOdd();
			using (var root = TestRootPanel.CreateWithChild(p))
			{
				Assert.IsTrue(p.b.Boolean);
				Assert.IsFalse(p.c.Boolean);
				
				p.a.Integer = -3;
				root.PumpDeferred();
				Assert.IsFalse(p.b.Boolean);
				Assert.IsTrue(p.c.Boolean);
				
				p.a.Float = 2.6f; //rounds to 3
				root.PumpDeferred();
				Assert.IsFalse(p.b.Boolean);
				Assert.IsTrue(p.c.Boolean);
				
				p.a.Float = -2.3f; //rounds to -2
				root.PumpDeferred();
				Assert.IsTrue(p.b.Boolean);
				Assert.IsFalse(p.c.Boolean);
			}
		}
		
		[Test]
		public void Alternate()
		{
			var p = new UX.MathFunctions.Alternate();
			using (var root = TestRootPanel.CreateWithChild(p))
			{
				Assert.IsFalse(p.b.Boolean);
				
				var ts = new[]{ -6, -5, -4, 0, 1, 2, 6 };
				var fs = new[]{ -7, -3, -2, -1, 3, 4, 5 };
				for (int i=0; i < ts.Length; ++i)
				{
					p.a.Integer = ts[i];
					root.PumpDeferred();
					Assert.IsTrue(p.b.Boolean);
					p.a.Integer = fs[i];
					root.PumpDeferred();
					Assert.IsFalse(p.b.Boolean);
				}
			}
		}
	}
}
