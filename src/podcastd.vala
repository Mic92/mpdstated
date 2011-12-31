/*
 * podcastd.vala
 *
 * Copyright 2011 Joerg Thalheim <joerg@turing-machine>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
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
        assert_no_mpd_err(conn);
        if (password != null) {
            if (!this.conn.run_password(password)) {
                throw new MpcError.AUTH("Password refused by server\n");
            }
        }
    }

    private void close_conn() {
        // free_function closes the socket too!
        this.conn = null;
    }

    private void assert_no_mpd_err(Mpd.Connection conn) throws MpcError {
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
                err = new MpcError.UNKNOWN(@"Failed to translate error code '$err_code': '$msg'\n");
                break;
        };
        if (!conn.clear_error()) on_close();

        throw err;
    }

    public void open_idle() throws MpcError {
        debug("open idle.\n");
        this.keep_idle = true;
        this.idle_conn = new Connection(this.host, this.port, 5);
        assert_no_mpd_err(this.idle_conn);
    }

    public void do_idle() throws MpcError {
        debug("do idle.\n");
        //TODO use idle mask
        var idle = this.idle_conn.run_idle();
        if (idle == 0) {
            assert_no_mpd_err(this.idle_conn);
            // if no error occurs
        } else {
            on_idle(idle);
        }
    }

    public void close_idle() {
        this.keep_idle = false;
        this.idle_conn.send_noidle();
        this.idle_conn = null;
    }

    public bool reconnect() {
        try {
            this.open_conn();
        } catch (MpcError e) {
            return false;
        }

        if (keep_idle) {
            try {
                this.open_idle();
            } catch (MpcError e) {
                return false;
            }
        }

        return true;
    }

    public Song? get_current_song() throws MpcError {
        debug("get current song!\n");
        var song = this.conn.run_current_song();

        if (song == null) {
            assert_no_mpd_err(conn);
        }

        return song;
    }

    public void seek_song(Song song, uint sec) throws MpcError {
        debug("seek id.\n");

        var res = this.conn.run_seek_id(song.id, sec);

        if (!res) {
            assert_no_mpd_err(conn);
        }
    }

    public uint get_elapsed_time(string uri) throws MpcError {
        debug("get elapsed time.\n");
        var res = this.conn.send_sticker_get("song", uri, "elapsed_time");

        if (!res) {
            assert_no_mpd_err(conn);
        }

        var pair = this.conn.recv_sticker();

        if (pair == null) {
            return 0;
        }

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
        debug("set elapsed time on %s.\n", uri);
        var res = this.conn.run_sticker_set("song", uri, "elapsed_time", sec.to_string());

        if (!res) {
            assert_no_mpd_err(conn);
        }
    }

    public Mpd.Status get_status() throws MpcError {
        debug("get status id.\n");
        var status = this.conn.run_status();

        if (status == null) {
            assert_no_mpd_err(conn);
        }
        return status;
    }

    public bool has_sticker() throws MpcError {
        debug("check sticker.\n");
        var res = this.conn.send_allowed_commands();

        if (!res) {
            assert_no_mpd_err(conn);
        }

        Pair pair = null;
        bool found = false;

        while(true) {
            pair = this.conn.recv_pair();
            if (pair == null)
                break;

            found = found || pair.value == "sticker";
            this.conn.return_pair(pair);
        };

        return found;
    }

}

public static void on_posix_finish(int sig) {
    message("Recieve kill signal. Goodbye!\n");
    Posix.exit(0);
}

class Main : Object {
    private static Mpc cli;
    public static MainContext app_context;

    private static string lastsong_uri;
    private static uint lastsong_pos;
    private static unowned string podcast_path = "podcast";

    public static void on_mpd_idle(int idle) {
        if (idle == Mpd.Idle.PLAYER) {
            debug("playstate changes!\n");
            try {
                var song = cli.get_current_song();
                if (song == null) return;
                if (lastsong_uri != null && song.uri != lastsong_uri) {
                    if (lastsong_uri.has_prefix(podcast_path)) {
                        debug("store podcast state\n");
                        cli.set_elapsed_time(lastsong_uri, lastsong_pos);
                    }
                    if (song.uri.has_prefix(podcast_path)) {
                        debug("restore podcast state\n");
                        var pos = cli.get_elapsed_time(song.uri);
                        if (pos != 0) {
                            cli.seek_song(song, pos);
                            lastsong_pos = pos;
                        }
                    }
                }
                lastsong_uri = song.uri.dup();
            } catch(MpcError e) {
                warning("Error while dispatching idle event: %s\n", e.message);
            }
        }
    }

    public static void on_mpd_close() {
        while(!cli.reconnect()) {
            stderr.printf("Fails to reconnet try it again in 10 sec!\n");
            Posix.sleep(10);
        }
        message("Reconnect successfully!\n");
    }

    public static int main(string[] args) {
        var loop = new MainLoop();
        var idle_timer  = new TimeoutSource(400);
        var state_timer = new TimeoutSource(1000);
        const string host = "localhost";
        const int port = 6600;

        // clear loghandler;
        Log.set_handler(null, LogLevelFlags.LEVEL_MASK, () => {return;});

        var log_mask = LogLevelFlags.LEVEL_ERROR | LogLevelFlags.FLAG_FATAL | LogLevelFlags.LEVEL_WARNING | LogLevelFlags.LEVEL_CRITICAL;
        Log.set_handler(null, log_mask, Log.default_handler);

        try {
            cli = new Mpc(host, port, null);
        } catch (MpcError e) {
            // TODO retry it instead
            error("Failed to connect to '%s:%d': %s\n", host, port, e.message);
        }

        try {
            if (!cli.has_sticker()) {
                error("Mpd didn't have sticker support! This is essentially needed!\n");
            }
        } catch (MpcError e) {
            error("Fail on check sticker support!\n");
        }

        idle_timer.set_callback(() => {
            try {
                cli.do_idle();
            } catch (MpcError e) {
                warning("Error while ideling: %s", e.message);
            }
            return true;
        });

        state_timer.set_callback(() => {
            int retry = 3;
            do {
                try {
                    var song = cli.get_current_song();
                    if (song == null) return true;
                    var status = cli.get_status();
                    if (song.uri.has_prefix(podcast_path)) {
                        lastsong_pos = status.get_elapsed_time();
                        debug("get podcast position: %us\n", lastsong_pos);
                    }
                    retry = 0;
                } catch (MpcError e) {
                    warning("Error while getting song updates: %s", e.message);
                    retry--;
                }
            } while(retry > 0);
            return true;
        });

        cli.on_idle.connect(on_mpd_idle);
        cli.on_close.connect(on_mpd_close);

        try {
            cli.open_idle();
        } catch (MpcError e) {
            error("Failed to going idle: %s\n", e.message);
        }

        app_context = loop.get_context();
        idle_timer.attach(app_context);
        state_timer.attach(app_context);

        Posix.signal(Posix.SIGQUIT, on_posix_finish);
        Posix.signal(Posix.SIGTERM, on_posix_finish);
        Posix.signal(Posix.SIGKILL, on_posix_finish);

        loop.run();
        return 1;
    }
}