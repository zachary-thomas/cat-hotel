using System;
using System.IO;
using System.Security.Cryptography;

namespace Purrington.Presentation
{
    public static class ParityProfile
    {
        public static bool TryOpen(string legacyRoot, out string profilePath, out string error)
        {
            profilePath=Path.Combine(Path.GetFullPath(legacyRoot),"parity-v2");error=null;
            try
            {
                string marker=Path.Combine(profilePath,"prototype-backup.complete");
                if(File.Exists(marker))return true;
                string archive=Path.Combine(legacyRoot,"prototype-backups",DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")+"-"+Guid.NewGuid().ToString("N"));
                foreach(string name in new[]{"hotel.0.save","hotel.1.save"})
                {
                    string source=Path.Combine(legacyRoot,name);
                    if(!File.Exists(source))continue;
                    Directory.CreateDirectory(archive);
                    byte[] original=File.ReadAllBytes(source);
                    string destination=Path.Combine(archive,name);
                    using(var stream=new FileStream(destination,FileMode.CreateNew,FileAccess.Write,FileShare.None))
                    {stream.Write(original,0,original.Length);stream.Flush(true);}
                    using(var sha=SHA256.Create())
                    {
                        string expected=Convert.ToBase64String(sha.ComputeHash(original));
                        string actual=Convert.ToBase64String(sha.ComputeHash(File.ReadAllBytes(destination)));
                        if(expected!=actual)throw new IOException("The prototype backup could not be verified.");
                    }
                }
                Directory.CreateDirectory(profilePath);
                File.WriteAllText(marker,"Original prototype journals retained. Verified backup location: "+archive);
                return true;
            }
            catch(Exception ex){error="Your original hotel is safe. Could not prepare its backup: "+ex.Message;return false;}
        }
    }
}
