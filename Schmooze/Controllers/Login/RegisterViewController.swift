//
//  RegisterViewController.swift
//  Schmooze
//
//  Created by MAD2 on 6/2/22.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

class RegisterViewController: UIViewController {
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
    
    private let firstNameField:UITextField = {
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
        field.placeholder = "First Name.."
        return field
    }()
    
    private let lastNameField:UITextField = {
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
        field.placeholder = "Last Name.."
        return field
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
    
    private let registerButton: UIButton = {
    let button = UIButton()
    button.setTitle("Sign Up", for: .normal)
        button.backgroundColor = .systemPurple
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
        
        registerButton.addTarget(self, action: #selector(registerButtonTapped), for: .touchUpInside)
        
        emailFeild.delegate = self
        passwordField.delegate = self
        //subview
        view.addSubview(scrollView)
        //add elements to our scroll view
        scrollView.addSubview(imageView)
        scrollView.addSubview(firstNameField)
        scrollView.addSubview(lastNameField)
        scrollView.addSubview(emailFeild)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(registerButton)
        

       
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (scrollView.width - size)/2,
                                 y: 20,
                                 width: size,
                                 height: size)
        firstNameField.frame = CGRect(x: 30,
                                 y: imageView.bottom+10,
                                 width: scrollView.width-60,
                                 height: 52)
        lastNameField.frame = CGRect(x: 30,
                                 y: firstNameField.bottom+10,
                                 width: scrollView.width-60,
                                 height: 52)
        
        emailFeild.frame = CGRect(x: 30,
                                 y: lastNameField.bottom+10,
                                 width: scrollView.width-60,
                                 height: 52)
        
        passwordField.frame = CGRect(x: 30,
                                 y: emailFeild.bottom+10,
                                 width: scrollView.width-60,
                                 height: 52)
        
        registerButton.frame = CGRect(x: 30,
                                 y: passwordField.bottom+10,
                                 width: scrollView.width-60,
                                 height: 52)
        
    }
    //check if there is text in both field and not empty
    @objc private func registerButtonTapped() {
        emailFeild.resignFirstResponder()
        passwordField.resignFirstResponder()
        firstNameField.resignFirstResponder()
        lastNameField.resignFirstResponder()

        guard let email = emailFeild.text,
              let firstName = firstNameField.text,
              let lastName = lastNameField.text,
              let password = passwordField.text,
              !email.isEmpty,
              !firstName.isEmpty,
              !lastName.isEmpty,
              !password.isEmpty else {
                  alertUserLoginError()
                  return
              }
        
        spinner.show(in: view)
        //login using firebase
        
        DatabaseManager.shared.userExists(with: email, completiton: { [weak self] exists in
            guard let strongSelf = self else {
                return
            }
            
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            guard !exists else {
                //user alr exists
                strongSelf.alertUserLoginError(message: "User already exists in that email address")
                return
            }
            
            FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password, completion: {authResult, error in guard authResult != nil ,error == nil else {
                    print("Error cureating user")
                    return
                }
                let chatUser = ChatAppUser(firstName: firstName, lastName: lastName, emailAddress: email)
                DatabaseManager.shared.insertUser(with: chatUser, completion: {sucess in
                    if sucess {
                        print("sucess")
                    }
                })
                
                strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            })
        })
        
        
            
            
    }
             
    func alertUserLoginError(message: String = "Please ensure all information are typed in."){
        let alert = UIAlertController(title: "Oops..?", message: message, preferredStyle: .alert
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

extension RegisterViewController:UITextFieldDelegate {
    
    func textFieldShouldReturn(textfield:UITextField) -> Bool {
        if textfield == emailFeild {
            passwordField.becomeFirstResponder()
        }
        else if textfield == passwordField {
                    registerButtonTapped()
        }
        return true
    }
    
}
