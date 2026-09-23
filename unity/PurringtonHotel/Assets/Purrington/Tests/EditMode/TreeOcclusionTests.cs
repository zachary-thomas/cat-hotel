using System.Collections;
using System.Linq;
using System.Reflection;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests
{
    public sealed class TreeOcclusionTests
    {
        static readonly BindingFlags Private = BindingFlags.Instance | BindingFlags.NonPublic;
        sealed class MemoryStore : ISaveStore { HotelState saved; public HotelState Load() => saved == null ? null : HotelModel.Copy(saved); public bool Save(HotelState s) { saved = HotelModel.Copy(s); return true; } }

        [Test]
        public void TreeBetweenCameraAndPlacementPreviewStepsAsideUntilThePreviewEnds()
        {
            var model = new HotelModel(new MemoryStore(), ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text));
            Assert.IsTrue(model.LoadOrCreate().success);
            var host = new GameObject("tree occlusion");
            try
            {
                var world = host.AddComponent<VoxelWorld>();
                world.Initialize(model);
                var update = typeof(VoxelWorld).GetMethod("UpdateTreeOcclusion", Private);
                update.Invoke(world, null);
                var trees = ((IEnumerable)typeof(VoxelWorld).GetField("trees", Private).GetValue(world)).Cast<object>().ToList();
                Assert.That(trees, Is.Not.Empty, "the meadow lawn has trees");
                var first = trees[0];
                var root = (Transform)first.GetType().GetField("Item1").GetValue(first);
                var bounds = (Bounds)first.GetType().GetField("Item2").GetValue(first);
                var renderRoot = (Transform)typeof(VoxelWorld).GetField("renderRoot", Private).GetValue(world);
                // Put the preview a few units behind the tree along the camera's view, on the ground.
                var behind = renderRoot.InverseTransformPoint(bounds.center + world.WorldCamera.transform.forward * 5);
                world.SetPlacementPreview(Catalog.All[0].id, new Vector3(behind.x / VoxelWorld.Unit, 0, behind.z / VoxelWorld.Unit), 0, true);
                update.Invoke(world, null);
                Assert.That(root.gameObject.activeSelf, Is.False, "tree in front of the preview hides");
                Assert.That(world.HiddenTreeCount, Is.GreaterThan(0));
                world.ClearPreview();
                update.Invoke(world, null);
                Assert.That(root.gameObject.activeSelf, Is.True, "tree returns once placement ends");
                Assert.That(world.HiddenTreeCount, Is.Zero);
            }
            finally { Object.DestroyImmediate(host); }
        }
    }
}
