import ManagedSettings
import ManagedSettingsUI
import UIKit

@objc(ShieldConfigurationExtension)
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let orange = UIColor(red: 1.0, green: 0.35, blue: 0.0, alpha: 1.0)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration()
    }

    private func configuration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.black,
            icon: UIImage(systemName: "scalemass.fill"),
            title: ShieldConfiguration.Label(
                text: "ONE OR OTHER",
                color: UIColor.white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "You can't use both screens at once. Close the laptop or lock this phone.",
                color: UIColor.lightGray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "LOCK PHONE",
                color: UIColor.black
            ),
            primaryButtonBackgroundColor: orange,
            secondaryButtonLabel: nil
        )
    }
}
