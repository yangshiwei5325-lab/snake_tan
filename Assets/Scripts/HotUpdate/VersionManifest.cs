using System;
using System.Collections.Generic;

// Manifest json of a lua hot-update package.
// path entries are relative to the package root and include the "lua/" prefix,
// e.g. "lua/Game/Main.lua".
[Serializable]
public class VersionManifest
{
    public string version;
    public List<ManifestEntry> files = new List<ManifestEntry>();
}

[Serializable]
public class ManifestEntry
{
    public string path;
    public string md5;
    public int size;
}

// The version that is currently applied in the persistent storage.
[Serializable]
public class AppliedVersion
{
    public string version;
    public string time;
}
