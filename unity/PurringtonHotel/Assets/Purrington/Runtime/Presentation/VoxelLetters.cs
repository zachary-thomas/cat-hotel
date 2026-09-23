using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace Purrington.Presentation
{
    // Chunky 5x7 voxel lettering for in-world signs. Letters are built as one recipe node so each sign bakes to a mesh per color.
    public static class VoxelLetters
    {
        const int Rows = 7;
        static readonly Dictionary<char, string[]> Glyphs = new Dictionary<char, string[]>
        {
            {'A', new[]{".###.","#...#","#...#","#####","#...#","#...#","#...#"}},
            {'B', new[]{"####.","#...#","#...#","####.","#...#","#...#","####."}},
            {'C', new[]{".###.","#...#","#....","#....","#....","#...#",".###."}},
            {'D', new[]{"####.","#...#","#...#","#...#","#...#","#...#","####."}},
            {'E', new[]{"#####","#....","#....","####.","#....","#....","#####"}},
            {'F', new[]{"#####","#....","#....","####.","#....","#....","#...."}},
            {'G', new[]{".###.","#...#","#....","#.###","#...#","#...#",".###."}},
            {'H', new[]{"#...#","#...#","#...#","#####","#...#","#...#","#...#"}},
            {'I', new[]{"#####","..#..","..#..","..#..","..#..","..#..","#####"}},
            {'J', new[]{"..###","...#.","...#.","...#.","#..#.","#..#.",".##.."}},
            {'K', new[]{"#...#","#..#.","#.#..","##...","#.#..","#..#.","#...#"}},
            {'L', new[]{"#....","#....","#....","#....","#....","#....","#####"}},
            {'M', new[]{"#...#","##.##","#.#.#","#.#.#","#...#","#...#","#...#"}},
            {'N', new[]{"#...#","##..#","#.#.#","#..##","#...#","#...#","#...#"}},
            {'O', new[]{".###.","#...#","#...#","#...#","#...#","#...#",".###."}},
            {'P', new[]{"####.","#...#","#...#","####.","#....","#....","#...."}},
            {'Q', new[]{".###.","#...#","#...#","#...#","#.#.#","#..#.",".##.#"}},
            {'R', new[]{"####.","#...#","#...#","####.","#.#..","#..#.","#...#"}},
            {'S', new[]{".####","#....","#....",".###.","....#","....#","####."}},
            {'T', new[]{"#####","..#..","..#..","..#..","..#..","..#..","..#.."}},
            {'U', new[]{"#...#","#...#","#...#","#...#","#...#","#...#",".###."}},
            {'V', new[]{"#...#","#...#","#...#","#...#","#...#",".#.#.","..#.."}},
            {'W', new[]{"#...#","#...#","#...#","#.#.#","#.#.#","##.##","#...#"}},
            {'X', new[]{"#...#","#...#",".#.#.","..#..",".#.#.","#...#","#...#"}},
            {'Y', new[]{"#...#","#...#",".#.#.","..#..","..#..","..#..","..#.."}},
            {'Z', new[]{"#####","....#","...#.","..#..",".#...","#....","#####"}},
            {'&', new[]{".##..","#..#.","#.#..",".#...","#.#.#","#..#.",".##.#"}},
            {' ', new[]{"...","...","...","...","...","...","..."}},
        };

        public static float Width(string text, float pixel)
        {
            float columns = 0;
            foreach (char c in text.ToUpperInvariant()) columns += (Glyphs.TryGetValue(c, out var g) ? g[0].Length : 3) + 1;
            return Mathf.Max(0, columns - 1) * pixel;
        }

        // Text reads along local +x, rows stack along +y, and the letters stand proud of the sign face along local -z by `depth`.
        public static JObject Recipe(string name, string text, float pixel, float depth, string color)
        {
            var parts = new JArray();
            float x = -Width(text, pixel) / 2;
            foreach (char raw in text.ToUpperInvariant())
            {
                if (!Glyphs.TryGetValue(raw, out var glyph)) glyph = Glyphs[' '];
                for (int row = 0; row < Rows; row++)
                    for (int col = 0; col < glyph[row].Length; col++)
                        if (glyph[row][col] == '#')
                        {
                            var at = new Vector3(x + (col + .5f) * pixel, ((Rows - 1 - row) + .5f - Rows / 2f) * pixel, -depth / 2);
                            parts.Add(new JObject { { "mesh", "cube" }, { "color", color }, { "transform", new JArray(pixel * .92f, 0, 0, 0, pixel * .92f, 0, 0, 0, depth, at.x, at.y, at.z) } });
                        }
                x += (glyph[0].Length + 1) * pixel;
            }
            return new JObject { { "name", name }, { "transform", new JArray(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0) }, { "parts", parts }, { "children", new JArray() } };
        }
    }
}
