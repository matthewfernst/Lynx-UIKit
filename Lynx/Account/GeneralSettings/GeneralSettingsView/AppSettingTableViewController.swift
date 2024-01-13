//
//  SettingsTableViewController.swift
//  Lynx
//
//  Created by Matthew Ernst on 1/25/23.
//

import UIKit

enum AppSettingSections: Int, CaseIterable {
    case units = 0
    case theme = 1
}

class AppSettingTableViewController: UITableViewController {
    
    static var identifier = "AppSettingTableView"
    
    var profile: Profile!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "App Settings"
        self.navigationItem.largeTitleDisplayMode = .never
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return AppSettingSections.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch AppSettingSections(rawValue: section) {
        case .units:
            return 1
        case .theme:
            return 1
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AppSettingCell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        
        switch AppSettingSections(rawValue: indexPath.section) {
        case .units:
            configuration.text = "Units"
            cell.accessoryView = getPopOverButtonForCell(isTheme: false)
            cell.accessoryView?.tintColor = .label
        case .theme:
            configuration.text = "Theme"
            cell.accessoryView = getPopOverButtonForCell(isTheme: true)
            cell.accessoryView?.tintColor = .label
        default:
            return UITableViewCell()
        }
        cell.contentConfiguration = configuration
        cell.backgroundColor = .secondarySystemBackground
        return cell
    }
    
    private func getPopOverButtonForCell(isTheme: Bool) -> UIButton {
        let pullDownButton = UIButton()
        
        pullDownButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        
        let chevronDown = UIImage(systemName: "chevron.down")?.scalePreservingAspectRatio(targetSize: CGSize(width: 14, height: 14)).withTintColor(.lightGray)
        pullDownButton.setImage(chevronDown, for: .normal)
        
        let chevronUp = UIImage(systemName: "chevron.up")?.scalePreservingAspectRatio(targetSize: CGSize(width: 14, height: 14)).withTintColor(.lightGray)
        pullDownButton.setImage(chevronUp, for: .highlighted)
        
        pullDownButton.semanticContentAttribute = .forceRightToLeft
        
        pullDownButton.menu = isTheme ? getThemeMenuActions() : getUnitMenuActions()
        pullDownButton.setTitleColor(.label, for: .normal)
        pullDownButton.showsMenuAsPrimaryAction = true
        pullDownButton.changesSelectionAsPrimaryAction = true
        pullDownButton.sizeToFit()
        
        let newWidth: CGFloat = 80
        let buttonHeight = pullDownButton.bounds.height
        pullDownButton.frame = CGRect(x: pullDownButton.frame.minX, y: pullDownButton.frame.minY, width: newWidth, height: buttonHeight)

        return pullDownButton
    }
    
    private func getThemeMenuActions() -> UIMenu {
        var menuOptions = [UIAction]()
        
        ["System", "Dark", "Light"].forEach { theme in
            let action = UIAction(title: theme) { [weak self] _ in
                if theme == "Dark" {
                    self?.setAppearance(.dark)
                } else if theme == "Light" {
                    self?.setAppearance(.light)
                } else {
                    self?.setAppearance(.unspecified)
                }
                self?.profile.appTheme = theme
                self?.saveTheme(theme: theme)
            }
            if theme == self.profile.appTheme {
                action.state = .on
            }
            menuOptions.append(action)
        }
        
        return UIMenu(children: menuOptions)
    }
    
    private func getUnitMenuActions() -> UIMenu {
        var menuOptions = [UIAction]()
        
        ["Imperial", "Metric"].forEach { measurementSystem in
            let action = UIAction(title: measurementSystem) { [weak self] _ in
                guard let selectedMeasurementSystem = MeasurementSystem(rawValue: measurementSystem.uppercased()) else {
                    return
                }
                self?.profile.measurementSystem = selectedMeasurementSystem
            }
            if measurementSystem.lowercased() == self.profile.measurementSystem.rawValue.lowercased() {
                action.state = .on
            }
            menuOptions.append(action)
        }
        
        return UIMenu(children: menuOptions)
    }
    
    func saveTheme(theme: String) {
        UserDefaults.standard.set(theme, forKey: UserDefaultsKeys.theme)
    }
    
    private func setAppearance(_ style: UIUserInterfaceStyle) {
        overrideUserInterfaceStyle = style
        self.tabBarController?.overrideUserInterfaceStyle = style
    }
    
}
