using System;
using UnityEditor;
using UnityEditor.PackageManager;
using UnityEditor.PackageManager.Requests;
using UnityEngine;
namespace Purrington.Editor
{
    public static class PackageInstaller
    {
        static AddAndRemoveRequest request;
        static double deadline;
        public static void EnsureParityDependencies()
        {
            request=Client.AddAndRemove(new[]{"com.unity.nuget.newtonsoft-json@3.2.2"},Array.Empty<string>());
            deadline=EditorApplication.timeSinceStartup+600;
            EditorApplication.update+=Poll;
        }
        public static void Install()
        {
            // The URP template already provides the runtime dependencies. Remove unrelated template tools.
            request=Client.AddAndRemove(Array.Empty<string>(),new[]{"com.unity.ai.navigation","com.unity.collab-proxy","com.unity.ide.rider","com.unity.multiplayer.center","com.unity.timeline","com.unity.visualscripting"});
            deadline=EditorApplication.timeSinceStartup+600;
            EditorApplication.update+=Poll;
        }
        static void Poll()
        {
            if(!request.IsCompleted){if(EditorApplication.timeSinceStartup>deadline){Debug.LogError("Package resolution timed out");EditorApplication.Exit(2);}return;}
            EditorApplication.update-=Poll;
            if(request.Status==StatusCode.Success){Debug.Log("PURRINGTON_PACKAGES_OK");EditorApplication.Exit(0);}
            else{Debug.LogError(request.Error.message);EditorApplication.Exit(1);}
        }
    }
}
