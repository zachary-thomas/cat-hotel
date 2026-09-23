using System.Collections.Generic;
using UnityEngine;

namespace Purrington.Presentation
{
    // While something is being placed, lawn trees standing between the camera and the placement preview step aside.
    public sealed partial class VoxelWorld
    {
        readonly List<(Transform root, Bounds bounds)> trees = new List<(Transform, Bounds)>();
        Transform treeScenery;

        public int HiddenTreeCount { get; private set; }

        void UpdateTreeOcclusion()
        {
            if (treeScenery != scenery) CollectTrees();
            bool placing = preview != null && preview.gameObject.activeInHierarchy && WorldCamera && !care;
            var target = placing ? WorldBounds(preview) : default;
            if (placing && target.size == Vector3.zero) placing = false;
            Rect targetRect = placing ? ScreenRect(target) : default;
            float targetDepth = placing ? Vector3.Dot(target.center - WorldCamera.transform.position, WorldCamera.transform.forward) : 0;
            int hidden = 0;
            foreach (var tree in trees)
            {
                if (!tree.root) continue;
                bool occludes = placing
                    && ScreenRect(tree.bounds).Overlaps(targetRect)
                    && Vector3.Dot(tree.bounds.center - WorldCamera.transform.position, WorldCamera.transform.forward) < targetDepth;
                if (tree.root.gameObject.activeSelf == occludes) tree.root.gameObject.SetActive(!occludes);
                if (occludes) hidden++;
            }
            HiddenTreeCount = hidden;
        }

        // Lawn plants and rocks authored where Main Street now stands are removed outright (not hidden), so occlusion never restores them.
        void ClearShopLots()
        {
            foreach (var node in scenery.GetComponentsInChildren<Transform>(true))
            {
                if (!node || node.name != "LifePart" || !node.parent) continue;
                var bounds = WorldBounds(node.parent);
                if (bounds.size == Vector3.zero) continue;
                if (!MainStreetArt.KeepScenery(renderRoot.InverseTransformPoint(bounds.center))) ReleaseWorldObject(node.parent.gameObject);
            }
            treeScenery = null;
        }

        void CollectTrees()
        {
            trees.Clear();
            treeScenery = scenery;
            if (!scenery) return;
            foreach (var node in scenery.GetComponentsInChildren<Transform>(true))
            {
                if (node.name != "LifePart" || !node.parent) continue;
                var bounds = WorldBounds(node.parent);
                if (bounds.size != Vector3.zero) trees.Add((node.parent, bounds));
            }
        }

        static Bounds WorldBounds(Transform root)
        {
            var result = new Bounds();
            bool any = false;
            foreach (var renderer in root.GetComponentsInChildren<Renderer>(true))
            {
                if (!any) { result = renderer.bounds; any = true; }
                else result.Encapsulate(renderer.bounds);
            }
            return result;
        }

        Rect ScreenRect(Bounds b)
        {
            float minX = float.MaxValue, minY = float.MaxValue, maxX = float.MinValue, maxY = float.MinValue;
            for (int i = 0; i < 8; i++)
            {
                var corner = b.center + Vector3.Scale(b.extents, new Vector3((i & 1) == 0 ? -1 : 1, (i & 2) == 0 ? -1 : 1, (i & 4) == 0 ? -1 : 1));
                var p = WorldCamera.WorldToScreenPoint(corner);
                minX = Mathf.Min(minX, p.x); maxX = Mathf.Max(maxX, p.x); minY = Mathf.Min(minY, p.y); maxY = Mathf.Max(maxY, p.y);
            }
            return Rect.MinMaxRect(minX, minY, maxX, maxY);
        }
    }
}
