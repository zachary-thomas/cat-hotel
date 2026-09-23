using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Globalization;

namespace Purrington.Domain
{
    /// <summary>Two independent checksummed slots. A failed or interrupted write never removes the newest valid slot.</summary>
    public sealed class JournalSaveStore : ISaveStore, ISaveStatus, IResettableSaveStore
    {
        readonly string path;
        readonly ISaveCodec codec;
        long sequence;
        bool recoveryBlocked, inspected;
        public bool HasExistingSave { get { return File.Exists(path+".0.save") || File.Exists(path+".1.save"); } }
        public string LoadError { get; private set; }
        public JournalSaveStore(string path,ISaveCodec codec){this.path=path;this.codec=codec;}
        public HotelState Load()
        {
            HotelState best=null;long newest=0;
            for(int slot=0;slot<2;slot++)
            {
                try
                {
                    string[] parts=File.ReadAllText(path+"."+slot+".save").Split(new[]{'\n'},3);
                    if(parts.Length!=3||!long.TryParse(parts[0],NumberStyles.Integer,CultureInfo.InvariantCulture,out long seq)||seq<=0||seq<=newest||parts[1]!=Hash(parts[2]))continue;
                    var candidate=codec.Deserialize(parts[2]);HotelModel.RepairTown(candidate);if(!HotelModel.Valid(candidate))continue;
                    newest=seq;best=candidate;
                }
                catch(Exception e) when(e is IOException||e is UnauthorizedAccessException||e is ArgumentException||e is FormatException||e is Newtonsoft.Json.JsonException||e is InvalidOperationException){ }
            }
            inspected=true;sequence=newest;recoveryBlocked=best==null&&HasExistingSave;
            LoadError=recoveryBlocked?"Neither saved hotel copy could be recovered. Your original files were preserved. Restore a backup before continuing.":null;return best;
        }
        public bool Save(HotelState state)
        {
            if(!inspected)Load();
            if(recoveryBlocked || !HotelModel.Valid(state))return false;
            try
            {
                string directory=Path.GetDirectoryName(path);if(!string.IsNullOrEmpty(directory))Directory.CreateDirectory(directory);
                long next=checked(sequence+1);string payload=codec.Serialize(state),slot=path+"."+(next%2)+".save",temporary=slot+".tmp";
                byte[] bytes=Encoding.UTF8.GetBytes(next.ToString(CultureInfo.InvariantCulture)+"\n"+Hash(payload)+"\n"+payload);
                using(var stream=new FileStream(temporary,FileMode.Create,FileAccess.Write,FileShare.None)){stream.Write(bytes,0,bytes.Length);stream.Flush(true);}
                // Only replace the older slot; latest committed slot is untouched throughout.
                // Windows can hold a just-written file briefly (antivirus, indexer); retry the swap before reporting a failed save.
                for(int attempt=0;;attempt++)
                {
                    try{if(File.Exists(slot))File.Replace(temporary,slot,null);else File.Move(temporary,slot);break;}
                    catch(Exception e) when((e is IOException||e is UnauthorizedAccessException)&&attempt<4){System.Threading.Thread.Sleep(25*(attempt+1));}
                }
                CleanupTemps();sequence=next;return true;
            }
            catch(Exception e) when(e is IOException||e is UnauthorizedAccessException||e is ArgumentException||e is InvalidOperationException||e is OverflowException){return false;}
        }
        public bool Reset(HotelState state)
        {
            if(!HotelModel.Valid(state))return false;
            string suffix=".before-reset-"+DateTime.UtcNow.Ticks+".bak";
            bool priorBlocked=recoveryBlocked;long priorSequence=sequence;
            try {
                for(int i=0;i<2;i++){string slot=path+"."+i+".save";if(File.Exists(slot))File.Copy(slot,slot+suffix,false);}
                inspected=true;recoveryBlocked=false;
                if(Save(state)){LoadError=null;return true;}
                recoveryBlocked=priorBlocked;sequence=priorSequence;return false;
            } catch(IOException){recoveryBlocked=priorBlocked;sequence=priorSequence;return false;}
              catch(UnauthorizedAccessException){recoveryBlocked=priorBlocked;sequence=priorSequence;return false;}
        }
        void CleanupTemps()
        {
            for(int i=0;i<2;i++)
            {
                string temporary=path+"."+i+".save.tmp";
                if(File.Exists(temporary))File.Delete(temporary);
            }
        }
        static string Hash(string value){using(var sha=SHA256.Create()){return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(value))).Replace("-","").ToLowerInvariant();}}
    }
}




