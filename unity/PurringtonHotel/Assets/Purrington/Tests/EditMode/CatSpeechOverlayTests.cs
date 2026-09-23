using NUnit.Framework;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests
{
    public sealed class CatSpeechOverlayTests
    {
        [TestCase(360, 640)]
        [TestCase(390, 844)]
        [TestCase(430, 932)]
        [TestCase(1280, 800)]
        public void BubbleStaysInsideAvailableWorld(int width, int height)
        {
            var area = new Rect(8, 140, width - 16, height - 240);
            Assert.That(CatSpeechOverlay.TryPlace(new Vector2(260, 100), area,
                new[] { new Vector2(width - 20, 160) }, new Rect[0], out var result), Is.True);
            Assert.That(result.xMin, Is.GreaterThanOrEqualTo(area.xMin));
            Assert.That(result.xMax, Is.LessThanOrEqualTo(area.xMax));
            Assert.That(result.yMax, Is.LessThanOrEqualTo(area.yMax));
        }

        [Test]
        public void SearchesHigherToKeepOtherCatsFacesClear()
        {
            var area = new Rect(0, 0, 390, 640);
            var face = new Rect(100, 200, 24, 20);
            Assert.That(CatSpeechOverlay.TryPlace(new Vector2(260, 100), area,
                new[] { new Vector2(60, 180), new Vector2(60, 250) }, new[] { face }, out var result), Is.True);
            Assert.That(result.y, Is.EqualTo(250));
        }

        [Test]
        public void HidesWhenNoReadablePlacementExists()
        {
            var area = new Rect(0, 0, 300, 120);
            Assert.That(CatSpeechOverlay.TryPlace(new Vector2(260, 100), area,
                new[] { new Vector2(10, 10) }, new[] { area }, out _), Is.False);
            Assert.That(CatSpeechOverlay.TryPlace(new Vector2(400, 100), area,
                new[] { Vector2.zero }, new Rect[0], out _), Is.False);
        }
    }
}
