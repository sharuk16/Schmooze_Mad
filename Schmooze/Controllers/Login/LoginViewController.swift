//
//  LoginViewController.swift
//  Schmooze
//
//  Created by MAD2 on 6/2/22.
//

import UIKit
import FirebaseAuth
import JGProgressHUD
class LoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let scrollView : UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let emailFeild:UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.borderWidth = 1
        field.layer.cornerRadius = 12
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.leftView = UIView(frame: CGRect (x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        field.placeholder = "Email Address.."
        return field
    }()
    
    private let passwordField:UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.borderWidth = 1
        field.layer.cornerRadius = 12
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.leftView = UIView(frame: CGRect (x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        field.placeholder = "Password .."
        field.isSecureTextEntry = true
        return field
    }()
    
    private let loginButton: UIButton = {
    let button = UIButton()
    button.setTitle("Log in", for: .normal)
        button.backgroundColor = .systemPink
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Log in"
        view.backgroundColor = .systemBackground
        
        //reg button
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register", style: .done , target: self, action: #selector(didTapRegister))
        
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        
        emailFeild.delegate = self
        passwordField.delegate = self
        //subview
        view.addSubview(scrollView)
        //add elements to our scroll view
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailFeild)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        

       
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (scrollView.width - size)/2,
                                 y: 20,
                                 width: size,
                                 height: size)
        
        emailFeild.frame = CGRect(x: 30,
                                 y: imageView.bottom+10,
                                 width: scrollView.width-60,
                                 height: 52)
        
        passwordField.frame = CGRect(x: 30,
                                 y: emailFeild.bottom+10,
                                 width: scrollView.width-60,
                                 height: 52)
        
        loginButton.frame = CGRect(x: 30,
                                 y: passwordField.bottom+10,
                                 width: scrollView.width-60,
                                 height: 52)
        
    }
    //check if there is text in both field and not empty
    @objc private func loginButtonTapped() {
        
        emailFeild.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailFeild.text, let password = passwordField.text,
              !email.isEmpty, !password.isEmpty else {
                  alertUserLoginError()
                  return
              }
        
        spinner.show(in: view)
        
        //login using firebase
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: {[weak self] authResult, error in
            guard let strongSelf = self else {
                return
            }
            
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            
            guard let result = authResult, error == nil else {
                print("failed to log in user with email: \(email)")
                return
            }
            let user = result.user
            
            let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
            DatabaseManager.shared.getDataFor(path: safeEmail, completion: { result in
                switch result {
                case .success(let data):
                    guard let userData = data as? [String: Any],
                    let firstName = userData["first_name"] as? String,
                    let lastName = userData["last_name"] as? String else {
                        return
                    }
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                case.failure(let error):
                    print("failed to read data: \(error)")
                }
            })
            //cache the user data for contacts
            
            UserDefaults.standard.set(email, forKey: "email")
            
            
            print("Logged in User: \(user)")
            //dismiss nav controller
            strongSelf.navigationController?.dismiss(animated: true, completion: nil)
        })
    }
             
    func alertUserLoginError(){
        let alert = UIAlertController(title: "Oops..?", message: "Please ensure all information are typed in ", preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel , handler: nil))
        
        present(alert, animated: true)
        
    }
    
    @objc private func didTapRegister(){
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension LoginViewController:UITextFieldDelegate {
    
    func textFieldShouldReturn(textfield:UITextField) -> Bool {
        if textfield == emailFeild {
            passwordField.becomeFirstResponder()
        }
        else if textfield == passwordField {
                    loginButtonTapped()
        }
        return true
    }
    
}
