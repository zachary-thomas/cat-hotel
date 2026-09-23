using System.Linq;
using NUnit.Framework;
using Purrington.Domain;
using Purrington.Presentation;
using UnityEngine;

namespace Purrington.Tests
{
    public sealed class HudTests
    {
        [Test]public void MoonIsFullAtNightAndHiddenAtNoon(){Assert.AreEqual(1f,HotelClockChip.MoonAmount(0),1e-4f);Assert.AreEqual(0f,HotelClockChip.MoonAmount(1),1e-4f);var dusk=HotelClockChip.MoonAmount(HotelClock.Daylight(1170));Assert.That(dusk,Is.InRange(.2f,.8f));}
        [Test]public void HudFontsCoverClockAndWalletGlyphs(){foreach(var name in new[]{"Fonts/Nunito SDF","Fonts/Fredoka SDF"}){var font=Resources.Load<TMPro.TMP_FontAsset>(name);Assert.IsNotNull(font,name);Assert.IsTrue(font.HasCharacters("0123456789·:+/ Daymin,",out var missing,false,true),name+" missing: "+(missing==null?"":string.Join("",missing)));}}
        [Test]public void CoinUsesOnlyCoinTokens(){var root=new GameObject("root",typeof(RectTransform)).GetComponent<RectTransform>();try{UiCoin.Create(root,null,26);foreach(var g in root.GetComponentsInChildren<UnityEngine.UI.Graphic>(true)){var a=g.color;Assert.That(new[]{ConceptTheme.Ui.Coin,ConceptTheme.Ui.CoinRim}.Any(b=>Mathf.Abs(a.r-b.r)<.01f&&Mathf.Abs(a.g-b.g)<.01f&&Mathf.Abs(a.b-b.b)<.01f),g.name);}}finally{Object.DestroyImmediate(root.gameObject);}}
    }
}
