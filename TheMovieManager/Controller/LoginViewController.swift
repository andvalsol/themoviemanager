//
//  LoginViewController.swift
//  TheMovieManager
//
//  Created by Owen LaRosa on 8/13/18.
//  Copyright © 2018 Udacity. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController {
    
    @IBOutlet weak var emailTextField: UITextField!
    
    @IBOutlet weak var passwordTextField: UITextField!
    
    @IBOutlet weak var loginButton: UIButton!
    
    @IBOutlet weak var loginViaWebsiteButton: UIButton!
    
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        emailTextField.text = ""
        passwordTextField.text = ""
    }
    
    @IBAction func loginTapped(_ sender: UIButton) {
        setLogginIn(true)
        
        TMDBClient.getRequestToken { (success, error) in
            self.handleRequestTokenResponse(success: success, error: error)
        }
    }
    
    func handleRequestTokenResponse(success: Bool, error: Error?) {
        if success {
            TMDBClient.login(username: self.emailTextField.text ?? "", password: self.passwordTextField.text ?? "") { (success, error) in
                self.handleLoginResponse(success: success, Error: error)
            }
        } else {
            showLoginFailure(message: error?.localizedDescription ?? "")
        }
    }
    
    @IBAction func loginViaWebsiteTapped() {
        setLogginIn(true)
        
        TMDBClient.getRequestToken { (success, error) in
            if success {
                UIApplication.shared.open(TMDBClient.Endpoints.webAuth.url, options: [:], completionHandler: nil)
            }
        }
    }
    
    func handleLoginResponse(success: Bool, Error: Error?) {
        if success {
            TMDBClient.createSession { (success, error) in
                self.handleSessionResponse(success: success, Error: error)
            }
        
        } else {
            showLoginFailure(message: Error?.localizedDescription ?? "")
        }
    }
    
    func handleSessionResponse(success: Bool, Error: Error?) {
        setLogginIn(false)
        
        if success {
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "completeLogin", sender: nil)
            }
        }
    }
    
    func showLoginFailure(message: String) {
        let alertVC = UIAlertController(title: "Login Failed", message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        show(alertVC, sender: nil)
    }
    
    func setLogginIn(_ logginIn: Bool) {
        if logginIn {
            loadingIndicator.startAnimating()
        
        } else {
            loadingIndicator.stopAnimating()
        }
        
        emailTextField.isEnabled = !logginIn
        passwordTextField.isEnabled = !logginIn
        loginButton.isEnabled = !logginIn
        loginViaWebsiteButton.isEnabled = !logginIn
    }
}
