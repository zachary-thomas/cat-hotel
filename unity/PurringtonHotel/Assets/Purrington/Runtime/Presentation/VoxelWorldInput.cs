using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;
namespace Purrington.Presentation { public sealed partial class VoxelWorld {        bool OverUI(Vector2 position)
        {
            if(EventSystem.current == null) return false;
            var result = new List<RaycastResult>();
            EventSystem.current.RaycastAll(new PointerEventData(EventSystem.current) { position=position }, result);
            return result.Count>0;
        }
        public static bool ShouldSendReleaseClick(bool dragged,bool overUI){return !dragged&&!overUI;}
        bool PickOnViewedFloor(WorldPick marker)
        {
            if(marker.catId>=0)return model.Actors.Any(a=>a.kind==Purrington.Domain.ActorKind.Guest&&a.catId==marker.catId&&a.floor==ViewFloor);
            for(var root=marker.transform;root!=null;root=root.parent)
                if(floorOf.TryGetValue(root,out int floor))return floor==ViewFloor;
            return true; // Unregistered scenery keeps its existing ground-click behavior.
        }
        void ReadInput()
        {
            if(storeInterior!=null&&storeInterior.IsVisible){
                Vector2 interiorPoint=default;bool released=false;
                if(Touchscreen.current!=null&&Touchscreen.current.primaryTouch.press.wasPressedThisFrame)interiorPointerOwned=!OverUI(Touchscreen.current.primaryTouch.startPosition.ReadValue());
                else if(Mouse.current!=null&&Mouse.current.leftButton.wasPressedThisFrame)interiorPointerOwned=!OverUI(Mouse.current.position.ReadValue());
                if(Touchscreen.current!=null&&Touchscreen.current.primaryTouch.press.wasReleasedThisFrame){interiorPoint=Touchscreen.current.primaryTouch.position.ReadValue();released=true;}
                else if(Mouse.current!=null&&Mouse.current.leftButton.wasReleasedThisFrame){interiorPoint=Mouse.current.position.ReadValue();released=true;}
                if(released&&interiorPointerOwned&&!OverUI(interiorPoint)){
                    var ray=WorldCamera.ScreenPointToRay(interiorPoint);
                    if(Physics.Raycast(ray,out var cashierHit,500)&&cashierHit.collider.GetComponent<StoreCashierHit>()!=null)storeInterior.SelectCashier();
                }
                if(released)interiorPointerOwned=false;
                pressed=false;return;
            }
            Vector2 point=default; bool start=false, held=false, end=false;
            var touch=Touchscreen.current;
            UnityEngine.InputSystem.Controls.TouchControl first=null,second=null;
            // Remember ownership from each finger's actual press, before it can slide off UI.
            if(touch != null) foreach(var finger in touch.touches) {
                if(!finger.press.isPressed) continue;
                int id=finger.touchId.ReadValue();
                if(finger.press.wasPressedThisFrame || !touchStartedOnWorld.ContainsKey(id))
                    touchStartedOnWorld[id]=finger.press.wasPressedThisFrame && !blocked && !care && !OverUI(finger.startPosition.ReadValue());
                if(blocked || care) touchStartedOnWorld[id]=false;
                if(first==null) first=finger; else if(second==null) second=finger;
            }
            endedTouchIds.Clear();
            foreach(int id in touchStartedOnWorld.Keys) {
                bool active=false;
                if(touch != null) foreach(var finger in touch.touches)
                    if(finger.press.isPressed && finger.touchId.ReadValue()==id) { active=true; break; }
                if(!active) endedTouchIds.Add(id);
            }
            foreach(int id in endedTouchIds) touchStartedOnWorld.Remove(id);
            if(blocked) { pressed=false; carePressed=false; pinchActive=false; pinchOwned=false; pinchDistance=0; return; }
            if(!care && first!=null && second!=null) {
                int firstId=first.touchId.ReadValue(),secondId=second.touchId.ReadValue();
                float distance=Vector2.Distance(first.position.ReadValue(),second.position.ReadValue());
                if(!pinchActive || pinchFirstId!=firstId || pinchSecondId!=secondId) {
                    // Latch once when the second finger joins. Moving onto the world never steals a UI gesture.
                    pinchActive=true; pinchFirstId=firstId; pinchSecondId=secondId; pinchMidValid=false;
                    pinchOwned=touchStartedOnWorld[firstId] && touchStartedOnWorld[secondId];
                    pinchDistance=pinchOwned?distance:0;
                    if(pinchOwned) previous=(first.position.ReadValue()+second.position.ReadValue())*.5f;
                } else if(pinchOwned) {
                    var mid=(first.position.ReadValue()+second.position.ReadValue())/2;
                    if(pinchMidValid) { townFollowing=false; manualCamera=true; focus += (ScreenToGround(pinchMid)-ScreenToGround(mid))*Unit; LimitCamera(); }
                    pinchMid=mid; pinchMidValid=true;
                    if(pinchDistance>0) manualCamera=true; if(pinchDistance>0) zoom=Mathf.Clamp(zoom*pinchDistance/Mathf.Max(distance,1),3,90);
                    pinchDistance=distance;
                }
                pressed=false; carePressed=false; return;
            }
            pinchActive=false; pinchOwned=false; pinchDistance=0;
            if(touch != null && (touch.primaryTouch.press.isPressed || touch.primaryTouch.press.wasReleasedThisFrame))
            { point=touch.primaryTouch.position.ReadValue(); start=touch.primaryTouch.press.wasPressedThisFrame; held=touch.primaryTouch.press.isPressed; end=touch.primaryTouch.press.wasReleasedThisFrame; }
            else if(Mouse.current != null)
            {
                point=Mouse.current.position.ReadValue(); start=Mouse.current.leftButton.wasPressedThisFrame; held=Mouse.current.leftButton.isPressed; end=Mouse.current.leftButton.wasReleasedThisFrame;
                // Input System normalizes wheel input to one unit per notch.
                // Proportional steps feel equally responsive near and far; trackpads retain fractional steps.
                if(!care && !OverUI(point) && Mouse.current.scroll.ReadValue().y!=0){townFollowing=false;manualCamera=true;zoom=Mathf.Clamp(zoom*Mathf.Pow(.85f,Mouse.current.scroll.ReadValue().y),3,90);}
            }
            if(care) {
                if(start && !OverUI(point)) carePressed=true;
                if(end) { if(carePressed && !OverUI(point)) GroundClicked?.Invoke(ScreenToGround(point)); carePressed=false; }
                return;
            }
            if(start && !OverUI(point)) { pressed=true; dragged=false; down=previous=point; }
            if(pressed && held)
            {
                if(Vector2.Distance(point,down)>10) dragged=true;
                if(pathPainting && !townMode) { GroundDragged?.Invoke(ScreenToGround(DrawPoint(point))); } else if(dragged) { townFollowing=false;manualCamera=true;focus += (ScreenToGround(previous)-ScreenToGround(point))*Unit; LimitCamera(); }
                previous=point;
            }
            if(end && pressed)
            {
                pressed=false; if(pathPainting && !townMode) GroundDragEnded?.Invoke();
                if(!ShouldSendReleaseClick(dragged,OverUI(point))) return;
                var ray=WorldCamera.ScreenPointToRay(point);
                var hits=Physics.RaycastAll(ray,500);
                System.Array.Sort(hits,(a,b)=>a.distance.CompareTo(b.distance));
                foreach(var hit in hits)
                {
                    var store=hit.collider.GetComponent<TownStoreHit>();
                    if(townMode&&store!=null){SelectTownStore(store.StoreId);return;}
                    if(townMode){SelectTownGround(ScreenToGround(point));return;}
                    var marker=hit.collider.GetComponent<WorldPick>();
                    if(marker==null)break;
                    if(!PickOnViewedFloor(marker))continue;
                    if(marker.catId<0&&string.IsNullOrEmpty(marker.objectId))continue; // staff, visitors and decor never block a pick behind them
                    if(marker.catId>=0) { CatSelected?.Invoke(marker.catId); return; }
                    if(!string.IsNullOrEmpty(marker.objectId)) { if(marker.objectId.StartsWith("room:")) RoomSelected?.Invoke(marker.objectId.Substring(5)); else ObjectSelected?.Invoke(marker.objectId); }
                    break;
                }
                if(townMode)SelectTownGround(ScreenToGround(point));else GroundClicked?.Invoke(ScreenToGround(point));
            }
        }
} }



