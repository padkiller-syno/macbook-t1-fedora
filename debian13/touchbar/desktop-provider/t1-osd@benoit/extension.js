// Bulle de niveau GNOME (OSD) accessible en D-Bus pour la Touch Bar (t1-desktop-provider).
// org.gnome.Shell.ShowOSD est refusé aux programmes extérieurs depuis GNOME 41 :
// cette extension tourne dans gnome-shell et appelle l'OSD natif.
//   gdbus call --session --dest org.gnome.Shell --object-path /fr/benoit/T1Osd \
//     --method fr.benoit.T1Osd.Show 'audio-volume-medium-symbolic' 0.4
import Gio from 'gi://Gio';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const IFACE = `
<node>
  <interface name="fr.benoit.T1Osd">
    <method name="Show">
      <arg type="s" name="icon" direction="in"/>
      <arg type="d" name="level" direction="in"/>
    </method>
  </interface>
</node>`;

export default class T1OsdExtension extends Extension {
    enable() {
        this._dbus = Gio.DBusExportedObject.wrapJSObject(IFACE, this);
        this._dbus.export(Gio.DBus.session, '/fr/benoit/T1Osd');
    }

    disable() {
        this._dbus?.unexport();
        this._dbus = null;
    }

    Show(icon, level) {
        const gicon = Gio.ThemedIcon.new(icon);
        const value = Math.max(0, Math.min(1, level));
        Main.osdWindowManager.show(-1, gicon, null, value, 1);  // -1 = tous les écrans (GNOME 48)
    }
}
