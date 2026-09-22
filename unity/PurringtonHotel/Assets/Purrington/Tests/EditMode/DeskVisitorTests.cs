using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using NUnit.Framework;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Tests
{
    public sealed class DeskVisitorTests
    {
        sealed class MemoryStore : ISaveStore
        {
            public bool fail;
            public HotelState Load() => null;
            public bool Save(HotelState state) => !fail;
        }

        [Test]
        public void CareAndAssistancePreferenceRollBackWhenSaveFails()
        {
            var content=ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);
            var store=new MemoryStore();var model=new HotelModel(store,content);
            Assert.That(model.LoadOrCreate().success,Is.True);
            var cat=model.State.cats.First(c=>c.known);int id=cat.id;
            model.State.elapsed=30;cat.lastCare=0;cat.bond=20;
            var codec=new NewtonsoftSaveCodec();string before=codec.Serialize(model.State);
            store.fail=true;
            Assert.That(model.Care(id,cat.favoriteAction).success,Is.False);
            Assert.That(codec.Serialize(model.State),Is.EqualTo(before),"Failed care must restore both friendship and cooldown.");
            Assert.That(model.SetAssistedCare(true).success,Is.False);
            Assert.That(codec.Serialize(model.State),Is.EqualTo(before));
            store.fail=false;
            Assert.That(model.Care(id,cat.favoriteAction).success,Is.True);
            Assert.That(model.State.cats.Single(c=>c.id==id).bond,Is.EqualTo(26));
            Assert.That(model.SetAssistedCare(true).success,Is.True);
            Assert.That(codec.Deserialize(codec.Serialize(model.State)).settings.assistedCare,Is.True);
        }

        HotelModel Model(bool empty = false)
        {
            var content = ParityContent.LoadJson(Resources.Load<TextAsset>("Content/GodotReference").text);
            var seed = content.CreateState();
            if (empty)
            {
                seed.hotels[0].rooms.Clear();
                seed.hotels[0].objects.Clear();
                seed.coins = 100000;
                for (int x = -12; x < 12; x++)
                    for (int z = -12; z < 12; z++)
                        seed.hotels[0].paths[x + "," + z] = new PathState();
            }
            var model = new HotelModel(new MemoryStore(), seed);
            Assert.That(model.LoadOrCreate().success, Is.True);
            return model;
        }

        VenueSnapshot Desk(HotelModel model, string item, int rotation)
        {
            Assert.That(model.Execute("place_room", new JObject { { "kind", "shared" }, { "x", -6 }, { "y", -6 }, { "w", 12 }, { "h", 12 } }).success, Is.True);
            var result = model.Execute("place_object", new JObject { { "item", item }, { "x", -1 }, { "y", -1 }, { "rotation", rotation } });
            Assert.That(result.success, Is.True, result.message);
            return model.Venues().Single(v => v.item == item);
        }

        [TestCase("reception_counter", 0)]
        [TestCase("reception_counter", 1)]
        [TestCase("reception_counter", 2)]
        [TestCase("reception_counter", 3)]
        [TestCase("milkshake_counter", 0)]
        [TestCase("milkshake_counter", 1)]
        [TestCase("milkshake_counter", 2)]
        [TestCase("milkshake_counter", 3)]
        public void StaffAndCustomersUseOppositeAuthoredSides(string item, int rotation)
        {
            var model = Model(true);
            var venue = Desk(model, item, rotation);
            Assert.That(venue.open, Is.True);
            Assert.That(venue.staffSlot, Is.Not.Null);
            float frontX = -(float)Math.Sin(rotation * Math.PI / 2);
            float frontZ = (float)Math.Cos(rotation * Math.PI / 2);
            Assert.That(venue.frontX, Is.EqualTo(frontX).Within(.0001));
            Assert.That(venue.frontZ, Is.EqualTo(frontZ).Within(.0001));
            Assert.That((venue.staffSlot.x - venue.centerX) * frontX + (venue.staffSlot.z - venue.centerZ) * frontZ, Is.LessThan(0));
            foreach (var slot in venue.slots)
            {
                Assert.That((slot.x - venue.centerX) * frontX + (slot.z - venue.centerZ) * frontZ, Is.GreaterThan(0));
                Assert.That(slot.key, Is.Not.EqualTo(venue.staffSlot.key));
                Assert.That(Math.Sin(slot.facing) * frontX + Math.Cos(slot.facing) * frontZ, Is.LessThan(-.99));
            }
            Assert.That(Math.Sin(venue.staffSlot.facing) * frontX + Math.Cos(venue.staffSlot.facing) * frontZ, Is.GreaterThan(.99));
        }

        [TestCase("reception_counter", 0)]
        [TestCase("reception_counter", 1)]
        [TestCase("reception_counter", 2)]
        [TestCase("reception_counter", 3)]
        [TestCase("milkshake_counter", 0)]
        [TestCase("milkshake_counter", 1)]
        [TestCase("milkshake_counter", 2)]
        [TestCase("milkshake_counter", 3)]
        public void BlockedCustomerFrontClosesServiceRatherThanUsingRear(string item, int rotation)
        {
            var model = Model(true);
            var venue = Desk(model, item, rotation);
            var desk = model.State.objects.Single(o => o.id == venue.id);
            HotelModel.Size(desk, out float width, out float depth);
            // Block the entire customer edge, including both half-grid snapping candidates.
            float length = rotation % 2 == 0 ? width : depth;
            for (float along = 0; along < length; along += .5f)
            {
                float x = rotation == 1 ? desk.x - .5f : rotation == 3 ? desk.x + width : desk.x + along;
                float z = rotation == 0 ? desk.z + depth : rotation == 2 ? desk.z - .5f : desk.z + along;
                var result = model.Execute("place_object", new JObject { { "item", "plant" }, { "x", x }, { "y", z }, { "rotation", 0 } });
                Assert.That(result.success, Is.True, result.message);
            }
            var blocked = model.Venues().Single(v => v.id == venue.id);
            Assert.That(blocked.open, Is.False);
            Assert.That(blocked.slots, Is.Empty);
            Assert.That(blocked.staffSlot, Is.Not.Null, "The unblocked rear is still reachable, but is not a customer fallback.");
        }

        [Test]
        public void DayVisitorsAreCappedAndDoNotChangeGuestProgressionOrIncomeRate()
        {
            var model = Model(true);
            foreach (int x in new[] { -7, -1, 5 })
            {
                Assert.That(model.Execute("place_object", new JObject { { "item", "milkshake_counter" }, { "x", x }, { "y", -3 }, { "rotation", 0 } }).success, Is.True);
                Assert.That(model.Execute("place_object", new JObject { { "item", "bench" }, { "x", x }, { "y", 0 }, { "rotation", 0 } }).success, Is.True);
            }
            // No overnight guests: any observed service activity belongs to day visitors.
            foreach (var cat in model.State.cats) cat.known = false;
            int capacity = model.GuestCapacity();
            double rate = model.Rate(), coins = model.State.coins;
            var bonds = model.State.cats.Select(c => c.bond).ToArray();
            int visits = model.Hotel().visits, happy = model.Hotel().happy;
            bool sawVisitor = false, sawDrink = false, sawDeparture = false;
            int peakVisitors = 0;
            const int steps = 600;
            for (int i = 0; i < steps; i++)
            {
                model.Tick(.2f);
                Assert.That(model.DayVisitorCount, Is.LessThanOrEqualTo(3));
                peakVisitors = Math.Max(peakVisitors, model.DayVisitorCount);
                Assert.That(model.Actors.Any(a => a.kind == ActorKind.Guest), Is.False);
                var visitors = model.Actors.Where(a => a.kind == ActorKind.DayVisitor).ToArray();
                sawVisitor |= visitors.Length > 0;
                sawDrink |= visitors.Any(a => a.action == "drink");
                sawDeparture |= visitors.Any(a => a.phase == "walk_depart");
            }
            Assert.That(sawVisitor, Is.True);
            Assert.That(peakVisitors, Is.EqualTo(3), "The simulation must exercise the visitor limit.");
            Assert.That(sawDrink, Is.True, "A visitor must complete service.");
            Assert.That(sawDeparture, Is.True, "A serviced visitor must leave.");
            Assert.That(model.CompletedDayVisits, Is.GreaterThan(0));
            Assert.That(model.GuestCapacity(), Is.EqualTo(capacity));
            Assert.That(model.Rate(), Is.EqualTo(rate));
            Assert.That(model.State.coins, Is.EqualTo(coins + rate * (.2f * steps) / 60).Within(.001));
            CollectionAssert.AreEqual(bonds, model.State.cats.Select(c => c.bond).ToArray());
            Assert.That(model.State.cats.Any(c => c.known), Is.False);
            Assert.That(model.Hotel().visits, Is.EqualTo(visits));
            Assert.That(model.Hotel().happy, Is.EqualTo(happy));
        }

        [Test]
        public void OldSaveDefaultsAssistedCareToDisabled()
        {
            var model = Model();
            var codec = new NewtonsoftSaveCodec();
            var json = JObject.Parse(codec.Serialize(model.State));
            ((JObject)json["settings"]).Remove("assistedCare");
            var restored = codec.Deserialize(json.ToString());
            Assert.That(restored.settings.assistedCare, Is.False);
            Assert.That(HotelModel.Valid(restored), Is.True);
        }

        HotelModel VisitorBar(out string counterId)
        {
            var model = Model(true);
            Assert.That(model.Execute("place_object", new JObject { { "item", "milkshake_counter" }, { "x", -4 }, { "y", -3 }, { "rotation", 0 } }).success, Is.True);
            counterId = model.State.objects.Single().id;
            Assert.That(model.Execute("place_object", new JObject { { "item", "bench" }, { "x", -4 }, { "y", 0 }, { "rotation", 0 } }).success, Is.True);
            return model;
        }

        static void TickUntil(HotelModel model, Func<bool> condition, float limit, string message)
        {
            for (float t = 0; t < limit && !condition(); t += .2f) model.Tick(.2f);
            Assert.That(condition(), Is.True, message);
        }

        [TestCase(false)]
        [TestCase(true)]
        public void MovingOrRotatingOccupiedCounterReleasesOldSlotsAndResumesVisits(bool rotate)
        {
            var model = VisitorBar(out string id);
            TickUntil(model, () => model.Actors.Any(a => a.kind == ActorKind.DayVisitor && a.phase == "order"), 60, "Visitor must reach the counter before editing it.");
            var visitor = model.Actors.First(a => a.kind == ActorKind.DayVisitor && a.phase == "order");
            string visitorId = visitor.id, oldCustomerSlot = visitor.slot;
            int visitorCatId = visitor.catId, completed = model.CompletedDayVisits;
            var oldVenue = model.Venues().Single(v => v.id == id);
            string oldStaffSlot = oldVenue.staffSlot.key;
            var change = model.Execute("move_object", new JObject { { "id", id }, { "x", rotate ? -4 : 2 }, { "y", -3 }, { "rotation", rotate ? 1 : 0 } });
            Assert.That(change.success, Is.True, change.message);
            model.Tick(.01f);
            var updated = model.Venues().Single(v => v.id == id);
            Assert.That(updated.open, Is.True);
            var staff = model.Actors.Single(a => a.kind == ActorKind.Staff && a.venueId == id);
            Assert.That(staff.x, Is.EqualTo(updated.staffSlot.x).Within(.001));
            Assert.That(staff.z, Is.EqualTo(updated.staffSlot.z).Within(.001));
            Assert.That(staff.facing, Is.EqualTo(updated.staffSlot.facing).Within(.001));
            Assert.That(model.Reservations[updated.staffSlot.key], Is.EqualTo(staff.catId));
            Assert.That(model.Reservations.TryGetValue(oldCustomerSlot, out int owner) && owner == visitorCatId, Is.False, "The visitor must release its former service slot.");
            var currentKeys = updated.slots.Select(s => s.key).Append(updated.staffSlot.key).ToArray();
            foreach (string obsolete in new[] { oldStaffSlot, oldCustomerSlot }.Where(k => !currentKeys.Contains(k)))
                Assert.That(model.Reservations.ContainsKey(obsolete), Is.False);
            TickUntil(model, () => model.CompletedDayVisits > completed, 90, "Visitors must recover and complete service after the layout change.");
            TickUntil(model, () => !model.Actors.Any(a => a.id == visitorId), 120, "The interrupted visitor must eventually leave safely.");
        }

        [Test]
        public void RemovingOccupiedCounterReleasesStaffAndVisitorsWithoutPhantomService()
        {
            var model = VisitorBar(out string id);
            TickUntil(model, () => model.Actors.Any(a => a.kind == ActorKind.DayVisitor && a.phase == "order"), 60, "Visitor must be ordering before removal.");
            var venue = model.Venues().Single(v => v.id == id);
            var oldKeys = venue.slots.Select(s => s.key).Append(venue.staffSlot.key).ToArray();
            int completed = model.CompletedDayVisits;
            Assert.That(model.Execute("store_object", new JObject { { "id", id } }).success, Is.True);
            model.Tick(.01f);
            Assert.That(model.Actors.Any(a => a.venueId == id), Is.False);
            foreach (string key in oldKeys) Assert.That(model.Reservations.ContainsKey(key), Is.False);
            TickUntil(model, () => model.DayVisitorCount == 0, 120, "Visitors must leave when their only counter is removed.");
            Assert.That(model.Reservations, Is.Empty);
            Assert.That(model.CompletedDayVisits, Is.EqualTo(completed), "Removed counters cannot finish an interrupted order.");
        }

        [Test]
        public void EditingLayoutPreservesAnExtendedStreetEntrance()
        {
            var model = VisitorBar(out string id);
            TickUntil(model, () => model.Actors.Any(a => a.kind == ActorKind.DayVisitor && a.phase == "enter"), 30, "Expected a transient street entrance.");
            var entering = model.Actors.First(a => a.kind == ActorKind.DayVisitor && a.phase == "enter");
            string visitorId = entering.id;
            model.ExtendVisitorEntry(entering.visitorIndex, 12);
            Assert.That(model.Execute("move_object", new JObject { { "id", id }, { "x", 2 }, { "y", -3 }, { "rotation", 0 } }).success, Is.True);
            model.Tick(.2f);
            var preserved = model.Actors.Single(a => a.id == visitorId);
            Assert.That(preserved.phase, Is.EqualTo("enter"));
            Assert.That(preserved.remaining, Is.GreaterThan(11.5f), "Construction must not teleport a street cat into its world rig.");
            Assert.That(preserved.slot, Is.Empty);
        }

        [TestCase("reception_counter", 0)]
        [TestCase("reception_counter", 1)]
        [TestCase("reception_counter", 2)]
        [TestCase("reception_counter", 3)]
        [TestCase("milkshake_counter", 0)]
        [TestCase("milkshake_counter", 1)]
        [TestCase("milkshake_counter", 2)]
        [TestCase("milkshake_counter", 3)]
        public void FrontAgainstWallCannotUseReachableRear(string item, int rotation)
        {
            var model = Model(true);
            var venue = Desk(model, item, rotation);
            int x = rotation == 1 ? -6 : rotation == 3 ? 5 : -4;
            int z = rotation == 0 ? 5 : rotation == 2 ? -6 : -4;
            var result = model.Execute("move_object", new JObject { { "id", venue.id }, { "x", x }, { "y", z }, { "rotation", rotation } });
            Assert.That(result.success, Is.True, result.message);
            var againstWall = model.Venues().Single(v => v.id == venue.id);
            Assert.That(againstWall.staffSlot, Is.Not.Null, "Staff can reach the rear from the room interior.");
            Assert.That(againstWall.slots, Is.Empty);
            Assert.That(againstWall.open, Is.False);
            model.Tick(.2f);
            Assert.That(model.Actors.Any(a => a.venueId == venue.id), Is.False);
        }
    }
}
