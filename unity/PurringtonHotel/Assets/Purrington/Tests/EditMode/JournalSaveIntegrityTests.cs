using System.IO;
using NUnit.Framework;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Tests
{
 public sealed class JournalSaveIntegrityTests
 {
  ParityContent Content() => ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);
  sealed class MemoryStore : ISaveStore
  {
   public bool fail;
   public HotelState saved;
   public HotelState Load() => saved == null ? null : HotelModel.Copy(saved);
   public bool Save(HotelState s) { if (fail) return false; saved = HotelModel.Copy(s); return true; }
  }
  HotelState Seed()
  {
   var m = new HotelModel(new MemoryStore(), Content());
   Assert.IsTrue(m.LoadOrCreate().success);
   return HotelModel.Copy(m.State);
  }
  string TempDir()
  {
   string d = Path.Combine(Path.GetTempPath(), "purrington-journal-" + Path.GetRandomFileName());
   Directory.CreateDirectory(d);
   return d;
  }

  [Test]
  public void NewerSlotSurvivesCorruptOlderSlot()
  {
   string dir = TempDir();
   try
   {
    string path = Path.Combine(dir, "hotel");
    var codec = new NewtonsoftSaveCodec();
    var store = new JournalSaveStore(path, codec);
    var first = Seed();
    Assert.IsTrue(store.Save(first));
    var second = HotelModel.Copy(first);
    second.coins += 25;
    Assert.IsTrue(store.Save(second));
    File.WriteAllText(path + ".1.save", "not-a-hotel");
    var loaded = new JournalSaveStore(path, codec).Load();
    Assert.IsNotNull(loaded);
    Assert.AreEqual(second.coins, loaded.coins, 0.001);
   }
   finally { Directory.Delete(dir, true); }
  }

  [Test]
  public void OrphanTempFilesDoNotHideValidSlot()
  {
   string dir = TempDir();
   try
   {
    string path = Path.Combine(dir, "hotel");
    var codec = new NewtonsoftSaveCodec();
    var store = new JournalSaveStore(path, codec);
    var state = Seed();
    state.coins = 777;
    Assert.IsTrue(store.Save(state));
    File.WriteAllText(path + ".0.save.tmp", "interrupted");
    File.WriteAllText(path + ".1.save.tmp", "interrupted");
    var loaded = new JournalSaveStore(path, codec).Load();
    Assert.IsNotNull(loaded);
    Assert.AreEqual(777, loaded.coins, 0.001);
    Assert.IsTrue(new JournalSaveStore(path, codec).Save(loaded));
    Assert.IsFalse(File.Exists(path + ".0.save.tmp"));
    Assert.IsFalse(File.Exists(path + ".1.save.tmp"));
   }
   finally { Directory.Delete(dir, true); }
  }

  [Test]
  public void BothCorruptSlotsBlockWritesUntilReset()
  {
   string dir = TempDir();
   try
   {
    string path = Path.Combine(dir, "hotel");
    var codec = new NewtonsoftSaveCodec();
    var store = new JournalSaveStore(path, codec);
    Assert.IsTrue(store.Save(Seed()));
    File.WriteAllText(path + ".0.save", "broken-a");
    File.WriteAllText(path + ".1.save", "broken-b");
    var blocked = new JournalSaveStore(path, codec);
    Assert.IsNull(blocked.Load());
    Assert.IsTrue(blocked.HasExistingSave);
    Assert.IsNotNull(blocked.LoadError);
    Assert.IsFalse(blocked.Save(Seed()));
    Assert.IsTrue(blocked.Reset(Seed()));
    Assert.IsNull(blocked.LoadError);
    Assert.IsNotNull(new JournalSaveStore(path, codec).Load());
   }
   finally { Directory.Delete(dir, true); }
  }

  [Test]
  public void FailedSaveKeepsProgressAndRetryMessage()
  {
   var store = new MemoryStore();
   var model = new HotelModel(store, Content());
   Assert.IsTrue(model.LoadOrCreate().success);
   store.fail = true;
   var failed = model.Save();
   Assert.IsFalse(failed.success);
   StringAssert.Contains("Retry", failed.message);
   store.fail = false;
   Assert.IsTrue(model.RetrySave().success);
  }
 }
}