[CCode (cheader_filename = "libportal/portal.h")]
namespace Xdp {
    [Flags]
    [CCode (cprefix = "XDP_USER_INFORMATION_FLAG_")]
    public enum UserInformationFlags {
        NONE;
    }

    [Flags]
    [CCode (cprefix = "XDP_BACKGROUND_FLAG_")]
    public enum BackgroundFlags {
        NONE,
        AUTOSTART,
        ACTIVATABLE;
    }

    [Flags]
    [CCode (cprefix = "XDP_CAMERA_FLAG_")]
    public enum CameraFlags {
        NONE;
    }

    [Flags]
    [CCode (cprefix = "XDP_EMAIL_FLAG_")]
    public enum EmailFlags {
        NONE;
    }

    [Flags]
    [CCode (cprefix = "XDP_OPEN_FILE_FLAG_")]
    public enum OpenFileFlags {
        NONE,
        MULTIPLE;
    }

    [Flags]
    [CCode (cprefix = "XDP_SAVE_FILE_FLAG_")]
    public enum SaveFileFlags {
        NONE;
    }

    [Flags]
    [CCode (cprefix = "XDP_INHIBIT_FLAG_")]
    public enum InhibitFlags {
        LOGOUT,
        USER_SWITCH,
        SUSPEND,
        IDLE;
    }

    [CCode (cprefix = "XDP_LOGIN_SESSION_")]
    public enum LoginSessionState {
        RUNNING,
        QUERY_END,
        ENDING;
    }

    [Flags]
    [CCode (cprefix = "XDP_SESSION_MONITOR_FLAG_")]
    public enum SessionMonitorFlags {
        NONE;
    }

    public enum LocationAcurracy {
        NONE,
        COUNTRY,
        CITY,
        NEIGHBORHOOD,
        STREET,
        EXACT;
    }

    [Flags]
    [CCode (cprefix = "XDP_LOCATION_MONITOR_FLAG_")]
    public enum LocationMonitorFlags {
        NONE;
    }

    [Flags]
    [CCode (cprefix = "XDP_NOTIFICATION_FLAG_")]
    public enum NotificationFlags {
        NONE;
    }

    [Flags]
    [CCode (cprefix = "XDP_OPEN_URI_FLAG_")]
    public enum OpenUriFlags {
        NONE,
        ASK,
        WRITABLE;
    }

    [Flags]
    [CCode (cprefix = "XDP_PRINT_FLAG_")]
    public enum PrintFlags {
        NONE;
    }

    [Flags]
    [CCode (cprefix = "XDP_OUTPUT_")]
    public enum OutputType {
        MONITOR,
        WINDOW;
    }

    [Flags]
    [CCode (cprefix = "XDP_DEVICE_")]
    public enum DeviceType {
        NONE,
        KEYBOARD,
        POINTER,
        TOUCHSCREEN;
    }

    [CCode (cprefix = "XDP_SESSION_")]
    public enum SessionType {
        SCREENCAST,
        REMOTE_DESKTOP;
    }

    [CCode (cprefix = "XDP_SESSION_")]
    public enum SessionState {
        INITIAL,
        ACTIVE,
        CLOSED;
    }

    [Flags]
    [CCode (cprefix = "XDP_SCREENCAST_FLAG_")]
    public enum ScreencastFlags {
        NONE,
        MULTIPLE;
    }

    [Flags]
    [CCode (cprefix = "XDP_REMOTE_DESKTOP_FLAG_")]
    public enum RemoteDesktopFlags {
        NONE,
        MULTIPLE;
    }

    [CCode (cprefix = "XDP_BUTTON_")]
    public enum ButtonState {
        RELEASED,
        PRESSED;
    }

    [CCode (cprefix = "XDP_AXIS_")]
    public enum DiscreteAxis {
        HORIZONTAL_SCROLL,
        VERTICAL_SCROLL;
    }

    [CCode (cprefix = "XDP_KEY_")]
    public enum KeyState {
        RELEASED,
        PRESSED;
    }

    [Flags]
    [CCode (cprefix = "XDP_SCREENSHOT_FLAG_")]
    public enum ScreenshotFlags {
        NONE,
        INTERACTIVE;
    }

    [Flags]
    [CCode (cprefix = "XDP_SPAWN_FLAG_")]
    public enum SpawnFlags {
        NONE,
        CLEARENV,
        LATEST,
        SANDBOX,
        NO_NETWORK,
        WATCH;
    }

    public enum UpdateStatus {
        RUNNING,
        EMPTY,
        DONE,
        FAILED;
    }

    [Flags]
    [CCode (cprefix = "XDP_UPDATE_MONITOR_FLAG_")]
    public enum UpdateMonitorFlags {
        NONE;
    }

    [Flags]
    [CCode (cprefix = "XDP_UPDATE_INSTALL_FLAG_")]
    public enum UpdateInstallFlags {
        NONE;
    }

    [Flags]
    [CCode (cprefix = "XDP_WALLPAPER_FLAG_")]
    public enum WallpaperFlags {
        NONE,
        BACKGROUND,
        LOCKSCREEN,
        PREVIEW,
        BOTH = BACKGROUND | LOCKSCREEN;
    }

    public sealed class Portal : GLib.Object {
        public Portal ();

        public async GLib.Variant get_user_information (Xdp.Parent? parent, string? reason, Xdp.UserInformationFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;

        public async bool request_background (Xdp.Parent? parent, string? reason, Xdp.BackgroundFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;

        public bool is_camera_present ();
        public async bool access_camera (Xdp.Parent? parent, string? reason, Xdp.CameraFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public int open_pipeware_remote_for_camera ();

        public async bool compose_email (Xdp.Parent? parent, string[]? addresses, string[]? cc, string[]? bcc, string? subject, string? body, string[]? attachments, Xdp.EmailFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;

        public async GLib.Variant open_file (Xdp.Parent? parent, string title, GLib.Variant? filters, GLib.Variant? currrent_filter, GLib.Variant? choices, Xdp.OpenFileFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public async GLib.Variant save_file (Xdp.Parent? parent, string title, string? current_name, string? current_folder, string? current_file, GLib.Variant? filters, GLib.Variant? currrent_filter, GLib.Variant? choices, Xdp.SaveFileFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public async GLib.Variant save_files (Xdp.Parent? parent, string title, string? current_name, string? current_folder, GLib.Variant files, GLib.Variant? choices, Xdp.SaveFileFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;

        public async int session_inhibit (Xdp.Parent? parent, string? reason, Xdp.InhibitFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public void session_uninhibit (int id);
        public async bool session_monitor_start (Xdp.Parent? parent, Xdp.SessionMonitorFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public void session_monitor_stop ();
        public void session_monitor_query_end_response ();

        public async bool location_monitor_start (Xdp.Parent? parent, uint distance_threshold, uint time_threshold, Xdp.LocationAcurracy accuracy, Xdp.LocationMonitorFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public void location_monitor_stop ();

        public async bool add_notification (string id, GLib.Variant notification, Xdp.NotificationFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public void remove_notification (string id);

        public async bool open_uri (Xdp.Parent? parent, string uri, Xdp.OpenUriFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public async bool open_directory (Xdp.Parent? parent, string uri, Xdp.OpenUriFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;

        public async GLib.Variant prepare_print (Xdp.Parent? parent, string title, GLib.Variant? settings, GLib.Variant? page_setup, Xdp.PrintFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public async bool print_file (Xdp.Parent? parent, string title, uint token, string file, Xdp.PrintFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;

        public async Xdp.Session create_screencast_session (Xdp.OutputType outputs, Xdp.ScreencastFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public async Xdp.Session create_remote_desktop_session (Xdp.DeviceType devices, Xdp.OutputType outputs, Xdp.RemoteDesktopFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;

        public async string? take_screenshot (Xdp.Parent? parent, Xdp.ScreenshotFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public async GLib.Variant pick_color (Xdp.Parent? parent, GLib.Cancellable? cancellable) throws GLib.Error;

        public async Posix.pid_t spaw (
            string cwd,
            [CCode (array_null_terminated = true )]
            string[] argv,
            [CCode (array_lenght_pos = 4.1)]
            int[]? fds,
            [CCode (array_lenght_pos = 4.1)]
            int[]? map_to,
            [CCode (array_null_terminated = true)]
            string[]? envs,
            Xdp.SpawnFlags flags,
            [CCode (array_null_terminated = true)]
            string[]? sandbox_expose,
            [CCode (array_null_terminated = true)]
            string[]? sandbox_expose_ro,
            GLib.Cancellable? cancellable
        ) throws GLib.Error;
        public void spaw_signal (Posix.pid_t pid, int @signal, bool to_process_group);

        public async bool trash_file (string path, GLib.Cancellable? cancellable) throws GLib.Error;

        public async bool update_monitor_start (Xdp.UpdateMonitorFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;
        public void update_monitor_stop ();
        public async bool update_install (Xdp.Parent parent, Xdp.UpdateInstallFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;

        public async bool set_wallpaper (Xdp.Parent parent, string uri, Xdp.WallpaperFlags flags, GLib.Cancellable? cancellable) throws GLib.Error;

        public signal void spawn_exited (uint id, uint exit_status);
        public signal void session_state_changed (bool screensaver_active, Xdp.LoginSessionState session_state);
        public signal void update_available (string running_commit, string local_commit, string remote_commit);
        public signal void update_progress (uint n_ops, uint op, uint progress, Xdp.UpdateStatus status, string error, string error_message);
        public signal void location_updated (int latitude, int longitude, int altitude, int accuracy, int speed, int heading, int64 timestamp_s, int64 timestamp_ms);
        public signal void notification_action_invoked (string id, string action, GLib.Variant? parameter);
    }

    [Compact]
    public class Parent {
        [CCode (has_emitter = false)]
        protected Parent ();
    }

    public delegate bool ParentExport (Xdp.Parent parent, Xdp.ParentExported callback);
    public delegate void ParentExported (Xdp.Parent parent, string handle);
    public delegate void ParentUnexport (Xdp.Parent parent);

    [CCode (cheader_filename = "libportal/portal-gtk3.h")]
    namespace Gtk3 {
        [Compact]
        [CCode (cname = "XdpParent", unref_function = "xdp_parent_free")]
        public class Parent : Xdp.Parent {
            [CCode (cname = "xdp_parent_new_gtk")]
            public Parent (Gtk.Window window);
        }
    }

    [CCode (cheader_filename = "libportal/portal-gtk4.h")]
    namespace Gtk4 {
        [Compact]
        [CCode (cname = "XdpParent", unref_function = "xdp_parent_free")]
        public class Parent : Xdp.Parent {
            [CCode (cname = "xdp_parent_new_gtk")]
            public Parent (Gtk.Window window);
        }
    }
    public sealed class Session : GLib.Object {
        public Xdp.SessionType session_type { get; }
        public Xdp.SessionState session_state { get; }
        public Xdp.DeviceType devices { get; }
        public GLib.Variant streams { get; }

        [CCode (has_emitter = false)]
        protected Session ();

        public async bool start (Xdp.Parent? parent, GLib.Cancellable? cancellable) throws GLib.Error;
        public void close ();
        public int open_pipeware_remote ();

        public void pointer_motion (double dx, double dy);
        public void pointer_position (uint stream, double x, double y);
        public void pointer_button (int button, Xdp.ButtonState state);
        public void pointer_axis (bool finish, double dx, double dy);
        public void pointer_axis_discrete (Xdp.DiscreteAxis axis, int steps);

        public void keyboard_key (bool keysym, int key, Xdp.KeyState state);
        public void touch_down (uint stream, uint slot, double x, double y);
        public void touch_position (uint stream, uint slot, double x, double y);
        public void touch_up (uint slot);

        public signal void closed ();
    }
}
