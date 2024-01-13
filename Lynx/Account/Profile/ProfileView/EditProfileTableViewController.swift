//
//  ProfileTableViewController.swift
//  Lynx
//
//  Created by Matthew Ernst on 1/25/23.
//

import UIKit
import OSLog

protocol EditProfileDelegate {
    func editProfileCompletionHandler(profile: Profile)
}

class EditProfileTableViewController: UITableViewController {
    public static var identifier = "EditProfileTableViewController"
    
    public var profile: Profile!
    
    var delegate: EditProfileDelegate?
    
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private var activityIndicatorBackground: UIView!
    
    private var profileChanges: [String: Any] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Edit Profile"
        self.navigationItem.largeTitleDisplayMode = .never
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(goBackToSettings))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveProfileChangesButtonTapped))
        
        self.tableView.delaysContentTouches = true
        
        tableView.register(EditProfilePictureTableViewCell.self, forCellReuseIdentifier: EditProfilePictureTableViewCell.identifier)
        tableView.register(EditNameTableViewCell.self, forCellReuseIdentifier: EditNameTableViewCell.identifier)
        tableView.register(EditEmailTableViewCell.self, forCellReuseIdentifier: EditEmailTableViewCell.identifier)
        
        // Add tap gesture recognizer to allow save button to be pressed even if we are in a textField
        let tapGesture = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tapGesture.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tapGesture)
    }
    
    @objc func goBackToSettings() {
        self.navigationController?.popViewController(animated: true)
    }
    
    func handleProfilePictureChange(newProfilePicture: UIImage?) {
        if newProfilePicture != nil {
            profileChanges[ProfileChangesKeys.profilePicture.rawValue] = newProfilePicture
        }
    }
    
    @objc func saveProfileChangesButtonTapped() {
        setupActivityIndicator()
        activityIndicator.startAnimating()
        Task.detached { [weak self] in
            await self?.saveProfileChanges()
        }
    }
    
    func setupActivityIndicator() {
        activityIndicatorBackground = UIView(frame: self.tabBarController!.view.frame)
        activityIndicatorBackground.backgroundColor = .black.withAlphaComponent(0.5)
        
        self.tabBarController!.view.addSubview(activityIndicatorBackground)
        
        activityIndicator.color = .white
        
        self.tabBarController!.view.addSubview(activityIndicator)
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
    }
    
    private func saveProfileChanges() async {
        let newFirstName = profileChanges[ProfileChangesKeys.firstName.rawValue] as? String ?? self.profile.firstName
        let newLastName = profileChanges[ProfileChangesKeys.lastName.rawValue] as? String ?? self.profile.lastName
        let newEmail = profileChanges[ProfileChangesKeys.email.rawValue] as? String ?? self.profile.email
        
        var newProfilePictureURL = self.profile.profilePictureURL
        let newProfilePicture = profileChanges.removeValue(forKey: ProfileChangesKeys.profilePicture.rawValue) as? UIImage
        if let newProfilePicture = newProfilePicture {
            ApolloLynxClient.createUserProfilePictureUploadUrl { result in
                switch result {
                case .success(let url):
                    
                    // Create the request object
                    newProfilePictureURL = url
                    guard let url = URL(string: url) else {
                        Logger.editProfileTableViewController.error("Couldn't convert string URL to normal URL.")
                        return
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "PUT"
                    
                    // Set the content type for the request
                    let contentType = "image/jpeg" // Replace with the appropriate content type
                    request.setValue(contentType, forHTTPHeaderField: "Content-Type")
                    
                    // Convert your image to data
                    guard let imageData = newProfilePicture.jpegData(compressionQuality: 0.8) else {
                        Logger.editProfileTableViewController.error("Couldn't covert changed profile picture to JPEG.")
                        return
                    }
                    
                    // Set the request body to the image data
                    request.httpBody = imageData
                    
                    // Create a URLSession task for the request
                    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                        if let error = error {
                            print("Error: \(error)")
                            return
                        }
                        
                        // Handle the response
                        if let response = response as? HTTPURLResponse {
                            print("Response status code: \(response.statusCode)")
                            // Handle the response data...
                        }
                    }
                    
                    // Start the task
                    task.resume()
                    
                case .failure(_):
                    Logger.editProfileTableViewController.error("Using profile before edit.")
                    return
                }
            }
        }
        
        ApolloLynxClient.editUser(profileChanges: profileChanges) { result in
            switch result {
            case .success(let returnedProfilePictureUrl):
                Logger.editProfileTableViewController.info("Retrieved new profile picture URL")
                newProfilePictureURL = returnedProfilePictureUrl
            case .failure(_):
                Logger.editProfileTableViewController.error("Using profile before edit.")
            }
            self.profile.editAttributes(newFirstName: newFirstName, newLastName: newLastName, newEmail: newEmail, newProfilePicture: newProfilePicture, newProfilePictureURL: newProfilePictureURL)
            
            
            self.delegate?.editProfileCompletionHandler(profile: self.profile)
            
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.activityIndicatorBackground.removeFromSuperview()
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    // MARK: - TableViewController Functions
    override func numberOfSections(in tableView: UITableView) -> Int {
        return EditProfileSections.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch EditProfileSections(rawValue: indexPath.section) {
        case .changeProfilePicture:
            return 150
        default:
            return -1
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 10
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch EditProfileSections(rawValue: section) {
        case .changeProfilePicture:
            return 1
        default:
            return 18
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch EditProfileSections(rawValue: section) {
        case .changeProfilePicture:
            return 1
        case .changeNameAndEmail:
            return 2
        case .mergeAccountsOrSignOut:
            return 2
        case .deleteAccount:
            return 1
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch EditProfileSections(rawValue: indexPath.section) {
        case .changeProfilePicture:
            guard let editProfileCell = tableView.dequeueReusableCell(withIdentifier: EditProfilePictureTableViewCell.identifier, for: indexPath) as? EditProfilePictureTableViewCell else {
                return UITableViewCell()
            }
            
            editProfileCell.configure(withProfile: self.profile, delegate: self)
            
            return editProfileCell
            
        case .changeNameAndEmail:
            switch NameAndEmailRows(rawValue: indexPath.row) {
            case .name:
                guard let editNameCell = tableView.dequeueReusableCell(withIdentifier: EditNameTableViewCell.identifier, for: indexPath) as? EditNameTableViewCell else {
                    return UITableViewCell()
                }
                
                editNameCell.configure(name: profile.name, delegate: self)
                
                return editNameCell
                
            case .email:
                guard let editEmailCell = tableView.dequeueReusableCell(withIdentifier: EditEmailTableViewCell.identifier, for: indexPath) as? EditEmailTableViewCell else { return UITableViewCell()
                }
                editEmailCell.configure(email: profile.email, delegate: self)
                
                return editEmailCell
            default:
                return UITableViewCell()
            }
            
        case .mergeAccountsOrSignOut:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath)
            var configuation = cell.defaultContentConfiguration()
            
            switch MergeAccountOrSignOutRows(rawValue: indexPath.row) {
            case .mergeAccounts:
                configuation.text = "Merge Accounts"
                configuation.image = UIImage(systemName: "person.2.gobackward")
                cell.accessoryType = .disclosureIndicator
                
            case .signOut:
                configuation.text = "Sign Out"
                configuation.image = UIImage(systemName: "door.right.hand.closed")
                
            default:
                break
            }
            
            configuation.textProperties.color = .systemBlue

            cell.backgroundColor = .secondarySystemBackground
            cell.contentConfiguration = configuation
            
            return cell

        case .deleteAccount:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath)
            var configuation = cell.defaultContentConfiguration()
            
            configuation.text = "Delete Account"
            configuation.textProperties.color = .systemRed
            
            configuation.image = UIImage(systemName: "trash.fill")
            configuation.imageProperties.tintColor = .systemRed
            
            cell.backgroundColor = .secondarySystemBackground
            cell.contentConfiguration = configuation
            
            cell.accessoryType = .disclosureIndicator
            
            return cell

        default:
            return UITableViewCell()
        }
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch EditProfileSections(rawValue: indexPath.section) {
        case .mergeAccountsOrSignOut:
            
            switch MergeAccountOrSignOutRows(rawValue: indexPath.row) {
            case .mergeAccounts:
                self.navigationController?.pushViewController(MergeAccountsViewController(), animated: true)
                
            case .signOut:
                LoginController.signOut()
                if let vc = self.storyboard?.instantiateInitialViewController() as? LoginViewController {
                    (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.changeRootViewController(vc)
                }
                
            default:
                break
            }

        case .deleteAccount:
            self.navigationController?.pushViewController(DeleteAccountViewController(), animated: true)
            
        default:
            break
        }
    }
    
}

// MARK: - Name and Email TextField Delegate
extension EditProfileTableViewController: UITextFieldDelegate
{
    
    private func setTextForProfile(text: String, tag: Int) {
        switch EditProfileTextFieldTags(rawValue: tag) {
        case .firstName:
            profileChanges[ProfileChangesKeys.firstName.rawValue] = text
        case .lastName:
            profileChanges[ProfileChangesKeys.lastName.rawValue] = text
        case .email:
            profileChanges[ProfileChangesKeys.email.rawValue] = text
        default:
            break
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        guard let text = textField.text else { return false }
        
        setTextForProfile(text: text, tag: textField.tag)
        
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard var text = textField.text else { return false }
        text = (text as NSString).replacingCharacters(in: range, with: string)
        
        setTextForProfile(text: text, tag: textField.tag)
        
        return true
    }
}

extension EditProfileTableViewController
{
    enum ProfileChangesKeys: String
    {
        case firstName = "firstName"
        case lastName = "lastName"
        case email = "email"
        case profilePicture = "profilePicture"
    }
}
