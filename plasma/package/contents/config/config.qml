import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Keys")
        icon: "network-server"
        source: "configpages/KeysConfig.qml"
    }
    ConfigCategory {
        name: i18n("General")
        icon: "settings-configure"
        source: "configpages/GeneralConfig.qml"
    }
}
