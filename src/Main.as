const string  pluginColor = "\\$A0A";
const string  pluginIcon  = Icons::Ubisoft;
Meta::Plugin@ pluginMeta  = Meta::ExecutingPlugin();
const string  pluginTitle = pluginColor + pluginIcon + "\\$G " + pluginMeta.Name;

bool         enabled = true;
const string host    = "127.0.0.1";
const uint16 port    = 4162;
bool         sending = false;
const string script  = IO::FromStorageFolder("UCannotPlay.py");
const string task    = IO::FromStorageFolder("UCannotPlay.xml");
const uint64 timeout = 5000;

#if TMNEXT
const uint16 year = 2020;
#elif TURBO
const uint16 year = 2016;
#endif

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

void Main() {
    if (!IO::FileExists(script)) {
        enabled = false;
        trace("writing script file");
        IO::FileSource assetsFile("assets/UCannotPlay.py");
        const string contents = assetsFile.ReadToEnd();
        IO::File storageFile(script, IO::FileMode::Write);
        storageFile.Write(contents);
        storageFile.Close();
        trace("wrote script file");
    }

    if (!IO::FileExists(task)) {
        enabled = false;
        trace("writing task file");
        IO::FileSource assetsFile("assets/UCannotPlay.xml");
        const string contents = assetsFile.ReadToEnd();
        IO::File storageFile(task, IO::FileMode::Write);
        storageFile.Write(contents.Replace("{script-path}", '"' + script + '"'));
        storageFile.Close();
        trace("wrote task file");
    }

    SendAsync();
}

void OnSettingsChanged() {
    startnew(SendAsync);
}

void RenderMenu() {
    if (UI::MenuItem(pluginTitle, "", S_Enabled)) {
        S_Enabled = !S_Enabled;
        startnew(SendAsync);
    }
}

void NotifyError(const string&in msg) {
    error(msg);
    UI::ShowNotification(pluginTitle, msg, vec4(1.0f, 0.0f, 0.0f, 0.8f));
}

void SendAsync() {
    if (!enabled) {
        NotifyError("plugin needs to be reloaded after your task is set up");
        return;
    }

    if (sending) {
        warn("already sending");
        return;
    }
    sending = true;

    trace("sending data...");

    Net::Socket@ sock = Net::Socket();

    if (!sock.Connect(host, port)) {
        NotifyError("failed to connect socket");
        sending = false;
        return;
    }

    const uint64 start = Time::Now;
    while (!sock.IsReady()) {
        yield();

        if (Time::Now - start > timeout) {
            NotifyError("socket failed to respond, is your Python script running?");
            sock.Close();
            return;
        }
    }

    MemoryBuffer@ buf = MemoryBuffer(2);
    buf.Write(S_Enabled ? year : uint16(0));
    buf.Seek(0);

    if (sock.Write(buf)) {
        trace("socket written");
    } else {
        error("socket failed to write");
    }

    sock.Close();

    sending = false;
}
