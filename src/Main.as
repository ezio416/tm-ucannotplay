const string  pluginColor = "\\$A0A";
const string  pluginIcon  = Icons::Ubisoft;
Meta::Plugin@ pluginMeta  = Meta::ExecutingPlugin();
const string  pluginTitle = pluginColor + pluginIcon + "\\$G " + pluginMeta.Name;

bool         enabled = true;
const string host    = "127.0.0.1";
const uint16 port    = 4162;
bool         sending = false;
const string script  = IO::FromStorageFolder("UCannotPlay.py");
const uint64 timeout = 5000;
const string version = IO::FromStorageFolder("version.txt");

#if TMNEXT
const uint16 year = 2020;
#elif TURBO
const uint16 year = 2016;
#endif

[Setting category="General" name="Enabled"]
bool S_Enabled = true;

void Main() {
    if (IO::FileExists(version)) {
        IO::File read(version, IO::FileMode::Read);
        const string v = read.ReadToEnd();
        read.Close();
        trace("previous plugin version: " + v);
    }

    try {
        IO::File write(version, IO::FileMode::Write);
        write.Write(pluginMeta.Version);
        write.Close();
    } catch {
        error("failed to write version file: " + getExceptionInfo());
        NotifyError("failed to write file, check log and contact Ezio if needed");
    }

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

[SettingsTab name="Setup" icon="Cogs"]
void SettingsTab_Setup() {
    UI::TextWrapped("It is recommended that you run this script with Task Scheduler, but you may run it however you like.");

    UI::Separator();

    if (UI::Selectable('Script location: "' + script + '"', false)) {
        IO::SetClipboard(Path::GetDirectoryName(script));
    }
    UI::SetItemTooltip("copy");
}
