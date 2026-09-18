"""Generate the auditable migration inventory from the frozen Godot export."""
import json, re, hashlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
content = root / 'unity/PurringtonHotel/Assets/Resources/Content'
source = json.loads((content / 'GodotReference.json').read_text())
rows = []
def add(key, feature, godot, unity, test, visual='Pending matched player capture and input verification', status='implemented'):
    rows.append(dict(id=key, feature=feature, godot=godot, unity=unity, behavioralEvidence=test, visualInputEvidence=visual, status=status))
for group, src, impl in [('items','creative_content.gd','GodotGeometry + Catalog'),('templates','creative_content.gd','HotelModel place_template'),('maps','creative_maps.gd','HotelState.hotels + VoxelWorld'),('cats','../core/game_content.gd','CatState + GodotCatRig'),('services','creative_model.gd','HotelModel upgrade'),('staff','../core/game_content.gd','HotelModel train')]:
    for index, entry in enumerate(source[group]):
        key = str(entry.get('id', index)) if isinstance(entry,dict) else str(index)
        name = str(entry.get('name',key)) if isinstance(entry,dict) else str(entry)
        add(group+'/'+key, name, 'scripts/creative/'+src, impl, 'tests/unity-domain/Program.cs; source fixture GodotReference.json')
for action in ['buy_plot','place_room','move_room','resize_room','copy_room','remove_room','place_template','place_object','move_object','retrieve_object','store_object','paint_path','erase_path','upgrade','train','hire_housekeeper','undo','redo','collect','travel','playdate','care','set_god_mode','grant_entitlement','reset','retry_save']:
    add('action/'+action, action.replace('_',' '), 'scripts/creative/creative_model.gd; creative_app.gd', 'HotelModel + HotelParityUI', 'GodotOracle.json; tests/unity-domain/Program.cs')
for setting in ['motion','music','sound','exterior','evening','ui_text_scale','god_mode']:
    add('setting/'+setting, setting, 'scripts/creative/creative_ui.gd', 'HotelParityUI + HotelState.settings', 'Pending full settings pointer matrix')
for feature, src, impl in [
    ('orthographic camera and wheel/pinch input','creative_world.gd','VoxelWorldInput'),
    ('six sidewalk cats per destination','creative_neighborhood.gd','NeighborhoodView'),
    ('arrival/check-in/roster turnover','creative_social.gd','HotelLife'),
    ('venue and seat reservations','creative_social.gd','HotelLife'),
    ('ordering/serving/drinking','creative_social.gd','HotelLife + GodotCatRig'),
    ('rest/sleep/play/sunbathe','creative_social.gd','HotelLife + GodotCatRig'),
    ('dirt/housekeeping','creative_model.gd; creative_social.gd','HotelLife'),
    ('conversations/gestures/friendship','creative_dialogue.gd; creative_life.gd','HotelLife + GodotCatRig'),
    ('fountain spillways/splashes','creative_water_motion.gd','GodotObjectMotion'),
    ('fire/embers/cafe/toy/litter/furniture effects','creative_object_motion.gd','GodotObjectMotion'),
    ('foliage/lamp/evening lighting','creative_world.gd','VoxelWorld'),
    ('context music and interaction audio','../audio/audio_director.gd','HotelAudio'),
    ('eight-hour offline income','creative_model.gd','HotelModel.Reconcile'),
    ('journal corruption/interrupted writes/rollback','../core/game_store.gd','JournalSaveStore'),
    ('prototype backup/new parity profile','Unity-only migration contract','ParityProfile'),
    ('return from care with live simulation','creative_ui.gd; creative_care_screen.gd','HotelUI + HotelApp'),
]: add('system/'+feature,feature,'scripts/creative/'+src,impl,'Pending final source-equivalence suite')
for tool in ['pet','brush','wand','yarn','cushion','box']:
    add('gesture/'+tool,tool+' interaction','scripts/creative/creative_care_stage.gd','CareGestureInput + VoxelWorldCare','Care rewards checked; pointer gesture evidence pending')
for test in sorted((root/'tests').glob('test_creative_*.gd')):
    add('suite/'+test.stem,test.stem,str(test.relative_to(root)),'tests/unity-domain; Unity EditMode; runtime acceptance','Godot baseline passed' if test.stem!='test_creative_lighting' else 'Native rendered baseline pending',status='missing')
for gate in ['Windows build','Android build','iOS export','dense Windows 60 FPS','physical Android/iOS 30 FPS','mobile signing']:
    add('delivery/'+gate,gate,'Approved full parity plan','Unity 6.3 build pipeline','Pending current integrated build verification',status='blocked' if gate in ['physical Android/iOS 30 FPS','mobile signing'] else 'missing')
ledger=dict(schema=1,sourceRevision='4be10cc8bd4979b2ccaaad7e2ce6c3708a7ba1ec',sourceHashes=source['sourceHashes'],exportHashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in content.glob('Godot*.json')},statusMeaning={'missing':'No completed equivalent verification or implementation yet','implemented':'Code present, full acceptance not yet established','verified':'Behavior and required visual/input evidence passed','blocked':'External prerequisite unavailable'},rows=rows)
folder=root/'docs/unity-migration'
(folder/'parity-ledger.json').write_text(json.dumps(ledger,indent=2),encoding='utf-8')
lines=['# Full migration parity ledger','','**Migration in progress. Implemented is not verified.** Source revision: `'+ledger['sourceRevision']+'`. Machine-readable evidence and source hashes: [parity-ledger.json](parity-ledger.json).','','Each source regression suite remains open until its Unity equivalent is explicitly mapped and run. Physical-device profiling and signing require hardware/credentials.','','| ID | Feature | Status | Unity implementation | Behavioral evidence | Visual/input evidence |','|---|---|---|---|---|---|']
for row in rows: lines.append('| '+' | '.join(str(row[k]).replace('|','/') for k in ['id','feature','status','unity','behavioralEvidence','visualInputEvidence'])+' |')
(folder/'PARITY-LEDGER.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(f'{len(rows)} parity rows written')
