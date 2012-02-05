/*
 * Licensed under the GNU General Public License v3
 * Copyright 2011 Jörg Thalheim <jthalheim@gmail.com>
 */

using Mpd;

errordomain MpcError {
    AUTH,
    ARGUMENT,
    CLOSED,
    MALFORMED,
    MEMORY,
    RESOLVER,
    STATE,
    SERVER,
    SYSTEM,
    TIMEOUT,
    UNKNOWN
}

class Mpc : Object {
    public signal void on_idle (int idle);
    public signal void on_close ();

    public Mpd.Connection conn;
    private Mpd.Connection idle_conn;

    private string host = "localhost";
    private string? password = null;
    private int port = 6600;

    private bool keep_idle = false;
    private Mpd.Idle idle_mask;

    public Mpc(string host, int port, string? password = null) throws MpcError {
        this.host = host;
        this.port = port;
        this.password = password;
        this.open_conn();
    }

    ~Mpc() {
        this.close_conn();
        if (this.keep_idle)
            this.close_idle();
    }

    private void open_conn() throws MpcError {
        this.conn = new Connection(host, port);
        assert_no_mpd_err(conn, false);
        if (password != null) {
            if (!this.conn.run_password(password)) {
                throw new MpcError.AUTH("Password refused by server");
            }
        }
    }

    private void close_conn() {
        // free_function closes the socket too!
        this.conn = null;
    }

    private void assert_no_mpd_err(Mpd.Connection conn, bool signal_on_close = true) throws MpcError {
        var mpd_err = conn.get_error();
        if (mpd_err == Mpd.Error.SUCCESS) return;

        string msg = conn.get_error_message();
        MpcError err;
        switch(mpd_err) {
            case Mpd.Error.ARGUMENT:
                err = new MpcError.ARGUMENT(msg); break;
            case Mpd.Error.OOM:
                err = new MpcError.MEMORY(msg); break;
            case Mpd.Error.MALFORMED:
                err = new MpcError.MALFORMED(msg); break;
            case Mpd.Error.RESOLVER:
                err = new MpcError.RESOLVER(msg); break;
            case Mpd.Error.STATE:
                err = new MpcError.STATE(msg); break;
            case Mpd.Error.SERVER:
                err = new MpcError.SERVER(msg); break;
            case Mpd.Error.SYSTEM:
                err = new MpcError.SYSTEM(msg); break;
            case Mpd.Error.TIMEOUT:
                err = new MpcError.TIMEOUT(msg); break;
            default:
                int err_code = mpd_err;
                err = new MpcError.UNKNOWN(@"Failed to translate error code '$err_code': '$msg'");
                break;
        };
        if (!conn.clear_error() && signal_on_close) on_close();

        throw err;
    }

    public void open_idle(Mpd.Idle mask) throws MpcError {
        debug("open idle.");
        this.keep_idle = true;
        this.idle_mask = mask;
        this.idle_conn = new Connection(this.host, this.port);
        assert_no_mpd_err(this.idle_conn, false);
        var chan = new IOChannel.unix_new(this.idle_conn.fd);
        chan.add_watch(IOCondition.ERR | IOCondition.HUP |
                       IOCondition.IN, check_idle);
        this.idle_conn.send_idle_mask(this.idle_mask);
    }

    public bool check_idle(IOChannel src, IOCondition cond) {
        debug("do idle.");

        var events = this.idle_conn.recv_idle(false);
        debug("idle event: %d", events);

        if (events == 0) {
            try {
                assert_no_mpd_err(this.idle_conn, false);
            } catch (MpcError e) {
                message("error while idleing: %s", e.message);
                if (!this.idle_conn.clear_error()) on_close();
                return false;
            }
        }
        on_idle(events);

        var res = this.idle_conn.send_idle_mask(this.idle_mask);

        if (!res) {
            try {
                assert_no_mpd_err(this.idle_conn, false);
            } catch (MpcError e) {
                message("error while idleing: %s", e.message);
                if (!this.idle_conn.clear_error()) on_close();
                return false;
            }
        }
        return true;
    }

    public void close_idle() {
        this.keep_idle = false;
        this.idle_conn.send_noidle();
        this.idle_conn = null;
    }

    public bool reconnect() {
        debug("reconnect");
        try {
            this.open_conn();
        } catch (MpcError e) {
            return false;
        }

        if (keep_idle) {
            try {
                this.open_idle(this.idle_mask);
            } catch (MpcError e) {
                return false;
            }
        }

        return true;
    }

    public Song? get_current_song() throws MpcError {
        debug("get current song!");
        var song = this.conn.run_current_song();

        if (song == null) {
            assert_no_mpd_err(conn);
        }

        return song;
    }

    public void seek_song(Song song, uint sec) throws MpcError {
        debug("seek id.");

        var res = this.conn.run_seek_id(song.id, sec);

        if (!res) {
            assert_no_mpd_err(conn);
        }
    }

    public uint get_elapsed_time(string uri) throws MpcError {
        debug("get elapsed time '%s'.", uri);
        var res = this.conn.send_sticker_get("song", uri, "elapsed_time");

        if (!res) {
            if (this.conn.get_error() == Mpd.Error.SERVER) {
                // sticker doesn't exist in this case.
                this.conn.clear_error();
                return 0;
            } else {
                assert_no_mpd_err(conn);
            }
        }

        var pair = this.conn.recv_sticker();
        assert_no_mpd_err(conn);

        var last_pos = int.parse(pair.value);
        this.conn.return_sticker(pair);

        // finish command
        while(pair != null) {
            pair = this.conn.recv_sticker();
            this.conn.return_sticker(pair);
        }

        return last_pos;
    }

    public void set_elapsed_time(string uri, uint sec) throws MpcError {
        debug("set elapsed time on '%s'.", uri);
        var res = this.conn.run_sticker_set("song", uri, "elapsed_time", sec.to_string());

        if (!res) {
            assert_no_mpd_err(conn);
        }
    }

    public Mpd.Status get_status() throws MpcError {
        debug("get status id.");
        var status = this.conn.run_status();

        if (status == null) {
            assert_no_mpd_err(conn);
        }
        return status;
    }

    public HashTable<string, bool> get_commands() throws MpcError {
        debug("get commands.");
        var res = this.conn.send_allowed_commands();
        if (!res) assert_no_mpd_err(conn);
        var table = new HashTable<string, bool>(str_hash, str_equal);

        while(true) {
            var pair = this.conn.recv_pair();
            if (pair == null) break;
            table.insert(pair.value, true);
            this.conn.return_pair(pair);
        }

        return table;
    }
// Client-To-Client protocol was introduced in libmpdclient v2.5
// debian and ubuntu currently only have v2.3
#if NO_CLIENT_TO_CLIENT
    private bool run_subscribe(string channel) {
        return this.conn.send_command("subscribe", channel, null) &&
            this.conn.response_finish();
    }

    private bool send_channels() {
        return this.conn.send_command("channels", null);
    }
#endif

    public void subscribe(string channel) throws MpcError {
#if NO_CLIENT_TO_CLIENT
        var res = this.run_subscribe(channel);
#else
        var res = this.conn.run_subscribe(channel);
#endif
        if (!res) assert_no_mpd_err(conn);
    }

    public bool has_channel(string channel) throws MpcError {
        debug("check channel.");
#if NO_CLIENT_TO_CLIENT
        var res = this.send_channels();
#else
        var res = this.conn.send_channels();
#endif
        if (!res) assert_no_mpd_err(conn);

        var found = false;
        while (true) {
            var pair = conn.recv_pair();
            if (pair == null)
                break;
            found = found || pair.value == channel;
            conn.return_pair(pair);
        }
        return found;
    }
}

public static void on_posix_finish(int sig) {
    message("Recieve kill signal. Save latest changes");
    if(Main.on_app_exit()) {
        Posix.exit(0);
    } else {
        Posix.exit(1);
    }
}

class Main : Object {
    // user_options
    private static string host = null;
    private static int port = 6600;
    private static string password = null;
    private static string track_path = null;
    private static bool verbose = false;
    private static bool no_daemon = false;

    const OptionEntry[] options = {
        { "host", 'h', 0, OptionArg.STRING, ref host,
            "address used to wait before swapping background [localhost]", "HOST" },
        { "port", 'p', 0, OptionArg.INT, ref port,
            "Port used to connect [6600] ", "PORT" },
        { "password", '\0', 0, OptionArg.STRING, ref password,
            "address used to connect []", "SECRET" },
        { "verbose", 'v', 0, OptionArg.NONE, ref verbose,
            "verbose logging [off]", null },
        { "no-daemon", '\0', 0, OptionArg.NONE, ref no_daemon,
            "don't detach from console [off]", null },
        { "track-path", 'd', 0, OptionArg.STRING, ref track_path,
            "tracked path relative to your music path [podcasts]", "PATH" },
        { null }
    };

    // Internal data
    private static Mpc cli;
    // state for the idle handler
    private static string lastsong_uri;
    private static uint lastsong_pos;
    private static Mpd.State lastsong_state;
    private static Timer lastsong_timer;

    public static bool on_app_exit() {
        if (lastsong_uri == null) return true;
        if (lastsong_uri.has_prefix(track_path)) {
            try {
                cli.set_elapsed_time(lastsong_uri, lastsong_pos);
            } catch (MpcError e) {
                message("Error saving changes: %s\n",e.message);
                return false;
            }
        }
        return true;
    }

    public static void on_mpd_idle(int idle) {
        try {
            var song = cli.get_current_song();
            if (song == null) return;
            var status = cli.get_status();

            if (lastsong_uri != null && song.uri != lastsong_uri) {
                if (lastsong_uri.has_prefix(track_path)) {
                    debug("store track state");
                    if (lastsong_state == Mpd.State.PLAY) {
                        lastsong_pos += (uint) lastsong_timer.elapsed();
                    }
                    try {
                        cli.set_elapsed_time(lastsong_uri, lastsong_pos);
                    } catch(MpcError e) {
                        // If the song is deleted before its time is saved, just go ahead.
                        if (!(e is MpcError.SERVER)) {
                            throw e;
                        }
                    }
                }
                if (song.uri.has_prefix(track_path)) {
                    debug("restore track state");
                    var pos = cli.get_elapsed_time(song.uri);
                    if (pos != 0) {
                        cli.seek_song(song, pos);
                        lastsong_pos = pos;
                    }
                }
            }

            lastsong_uri   = song.uri.dup();
            lastsong_pos   = status.get_elapsed_time();
            lastsong_state = status.get_state();
            lastsong_timer.start();
        } catch(MpcError e) {
            warning("Error while dispatching idle event: %s", e.message);
        }
    }

    public static void on_mpd_close() {
        while(!cli.reconnect()) {
            stderr.printf("Fails to reconnet try it again in 5 sec!");
            Posix.sleep(5);
        }
        message("Reconnect successfully!");
    }

    public static int main(string[] args) {
        var loop = new MainLoop();
        HashTable<string, bool> mpd_cmds = null;

        try {
            var opt = new OptionContext("- Auto restore recent position for each track in mpd");
            opt.set_help_enabled(true);
            opt.add_main_entries(options, null);
            opt.parse(ref args);
        } catch (GLib.Error e) {
            stderr.printf("Error: %s\n", e.message);
            stderr.printf("Run '%s --help' to see a full list of available "+
                    "options\n", args[0]);
            return Posix.EXIT_FAILURE;
        }
        // default values
        if (host == null) host = "localhost";
        if (track_path == null) track_path = "podcasts";

        if (!verbose) {
            // clear loghandler;
            Log.set_handler(null, LogLevelFlags.LEVEL_MASK, () => {return;});

            var log_mask = LogLevelFlags.LEVEL_ERROR | LogLevelFlags.FLAG_FATAL | LogLevelFlags.LEVEL_MESSAGE
                | LogLevelFlags.LEVEL_WARNING | LogLevelFlags.LEVEL_CRITICAL;
            Log.set_handler(null, log_mask, Log.default_handler);
        }

        // if connection fails the first time, retry it.
        // maybe mpd is not ready yet (on startup)
        for (var is_online = false; !is_online; Posix.sleep(10)) {
            try {
                cli = new Mpc(host, port, password);
                is_online = true;
            } catch (MpcError e) {
                warning("Failed to connect to '%s:%d': %s", host, port, e.message);
                is_online = false;
                continue;
            }
            message("Successfully connected to %s:%d", host, port);

            try {
                mpd_cmds = cli.get_commands();
            } catch (MpcError e) {
                warning("Fail on lookup avaible commands: %s", e.message);
                is_online = false;
                continue;
            }

            if (!mpd_cmds.lookup("sticker")) {
                warning("Mpd didn't have sticker support! This is essentially needed!");
                Posix.exit(Posix.EXIT_FAILURE);
            }

            if (mpd_cmds.lookup("channels")) {
                try {
                    if (cli.has_channel("mpdstated")) {
                        message("Found another mpdstated instance. Quit!");
                        Posix.exit(Posix.EXIT_SUCCESS);
                    }
                } catch (MpcError e) {
                    warning("Fail on subscribing to mpdstated channel: %s", e.message);
                    is_online = false;
                    continue;
                }
                try {
                    cli.subscribe("mpdstated");
                } catch (MpcError e) {
                    warning("Fail on subscribing channel: %s", e.message);
                    is_online = false;
                    continue;
                }
            }

            cli.on_idle.connect(on_mpd_idle);
            cli.on_close.connect(on_mpd_close);
            // set initial state for idle handler
            lastsong_timer = new Timer();
            on_mpd_idle(0);

            try {
                cli.open_idle(Mpd.Idle.PLAYER);
            } catch (MpcError e) {
                warning("Failed to going idle: %s", e.message);
                is_online = false;
                continue;
            }
            break;
        }

        Posix.signal(Posix.SIGINT, on_posix_finish);
        Posix.signal(Posix.SIGQUIT, on_posix_finish);
        Posix.signal(Posix.SIGTERM, on_posix_finish);

        if (!no_daemon) {
            var pid = Posix.fork();
            if (pid == -1) {
                warning("Failed to fork into background\n");
            } else if (pid != 0) {
                message("fork into background\n");
                Posix.exit(Posix.EXIT_SUCCESS);
            }
        }
        loop.run();
        return Posix.EXIT_SUCCESS;
    }
}
