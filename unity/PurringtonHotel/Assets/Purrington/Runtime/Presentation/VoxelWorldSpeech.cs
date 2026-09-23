using System.Collections.Generic;
using System.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation
{
    public sealed partial class VoxelWorld
    {
        CatSpeechOverlay speechOverlay;
        readonly List<Rect> speechProtected = new List<Rect>();
        string serviceSpeaker, serviceVenue, serviceGuest;
        long serviceToken = -1;
        float nextServiceSpeech, serviceStart;
        string serviceLine;
        float serviceDuration;
        bool awaitingServiceReply;
        int speechMap = -1;
        float speechClock;

        void LateUpdate()
        {
            if (model == null || !WorldCamera) return;
            if (speechMap != currentMap || model.State.elapsed < speechClock)
            {
                serviceSpeaker = serviceGuest = serviceVenue = null;
                serviceToken = -1;
                nextServiceSpeech = 0;
                awaitingServiceReply = false;
                speechMap = currentMap;
            }
            speechClock = model.State.elapsed;
            if (!speechOverlay) speechOverlay = CatSpeechOverlay.Create(transform);
            if (care || blocked) { speechOverlay.Hide(); return; }
            var snapshots = model.Actors;
            ActorSnapshot selected = null;
            string text = "";
            float elapsed = 0, duration = 3.1f;
            if (model.SocialActive)
            {
                // Silence between conversation lines belongs to the conversation too.
                selected = snapshots.FirstOrDefault(a => !string.IsNullOrEmpty(a.speech) && (a.gesture == "talk" || a.gesture == "happy"));
                if (selected != null) { text = selected.speech; elapsed = selected.speechElapsed; duration = selected.speechDuration; }
            }
            else
            {
                selected = snapshots.FirstOrDefault(a => a.id == serviceSpeaker && a.activityToken == serviceToken);
                if (selected == null || model.State.elapsed - serviceStart >= serviceDuration)
                {
                    selected = null;
                    if (awaitingServiceReply)
                    {
                        var customer = snapshots.FirstOrDefault(a => a.id == serviceGuest && a.venueId == serviceVenue && (a.phase == "order" || a.phase == "serve"));
                        if (customer == null) awaitingServiceReply = false;
                        else if (customer.phase == "serve") selected = snapshots.FirstOrDefault(a => a.venueId == serviceVenue && a.action == "serve" && a.kind == ActorKind.Staff && SpeechVisible(a));
                        if (selected != null) { BeginServiceLine(selected, "Coming right up!", 2.7f); awaitingServiceReply = false; }
                    }
                    if (selected == null && model.State.elapsed >= nextServiceSpeech)
                    {
                        selected = snapshots.FirstOrDefault(a => a.action == "order" && a.activityElapsed < .8f && SpeechVisible(a));
                        if (selected != null)
                        {
                            BeginServiceLine(selected, "One shake, please!", 1.9f);
                            serviceVenue = selected.venueId;
                            serviceGuest = selected.id;
                            awaitingServiceReply = true;
                            nextServiceSpeech = model.State.elapsed + 9;
                        }
                    }
                }
                if (selected != null) { text = serviceLine; elapsed = model.State.elapsed - serviceStart; duration = serviceDuration; }
            }
            if (selected == null || !SpeechVisible(selected)) { speechOverlay.Hide(); return; }
            var rig = actors[selected.id];
            var anchor = WorldCamera.WorldToScreenPoint(rig.Root.position + Vector3.up * 1.3f);
            speechProtected.Clear();
            foreach (var actor in actors.Values)
            {
                if (!actor.Root.gameObject.activeInHierarchy || !actor.Bindings.TryGetValue("head", out var head)) continue;
                var min = new Vector2(float.PositiveInfinity, float.PositiveInfinity);
                var max = new Vector2(float.NegativeInfinity, float.NegativeInfinity);
                foreach (var renderer in head.GetComponentsInChildren<MeshRenderer>())
                {
                    var bounds = renderer.bounds;
                    for (int i = 0; i < 8; i++)
                    {
                        var corner = bounds.center + Vector3.Scale(bounds.extents, new Vector3((i & 1) == 0 ? -1 : 1, (i & 2) == 0 ? -1 : 1, (i & 4) == 0 ? -1 : 1));
                        var point = WorldCamera.WorldToScreenPoint(corner);
                        if (point.z <= 0) continue;
                        min = Vector2.Min(min, point); max = Vector2.Max(max, point);
                    }
                }
                if (!float.IsInfinity(min.x)) speechProtected.Add(Rect.MinMaxRect(min.x, min.y, max.x, max.y));
            }
            // HotelUI supplies a viewport already excluding headers, sheets, overview and dock.
            var area = VisibleWorldRect();
            area = Rect.MinMaxRect(area.xMin + 5, area.yMin + 5, area.xMax - 5, area.yMax - 5);
            speechOverlay.Present(selected.name, text, selected.gesture, anchor, area, speechProtected,
                model.State.settings.textScale, model.State.settings.motion, elapsed, duration);
        }

        void BeginServiceLine(ActorSnapshot actor, string text, float duration)
        { serviceSpeaker = actor.id; serviceToken = actor.activityToken; serviceLine = text; serviceStart = model.State.elapsed; serviceDuration = duration; }

        bool SpeechVisible(ActorSnapshot actor)
        {
            if (!actors.TryGetValue(actor.id, out var rig) || !rig.Root.gameObject.activeInHierarchy) return false;
            if (exterior)
                foreach (var room in model.State.rooms)
                {
                    if (room.kind == "terrace") continue;
                    HotelModel.RoomSize(room, out float w, out float d);
                    if (actor.x >= room.x && actor.x <= room.x + w && actor.z >= room.z && actor.z <= room.z + d) return false;
                }
            var point = WorldCamera.WorldToScreenPoint(rig.Root.position + Vector3.up * 1.3f);
            return point.z > 0 && VisibleWorldRect().Contains(point);
        }
    }
}
