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

        // if (v != pluginMeta.Version) {
        //     trace("plugin updated, was: " + v);

        //     if (IO::FileExists(script)) {
        //         try {
        //             IO::Delete(script);
        //         } catch {
        //             error("failed to delete script file: " + getExceptionInfo());
        //             NotifyError("problem with plugin update, check log and contact Ezio if needed");
        //             return;
        //         }
        //     }

        //     if (IO::FileExists(task)) {
        //         try {
        //             IO::Delete(task);
        //         } catch {
        //             error("failed to delete task file: " + getExceptionInfo());
        //             NotifyError("problem with plugin update, check log and contact Ezio if needed");
        //             return;
        //         }
        //     }
        // }
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
