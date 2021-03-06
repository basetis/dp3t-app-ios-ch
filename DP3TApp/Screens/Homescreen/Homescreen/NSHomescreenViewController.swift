/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import CoreBluetooth
import SnapKit
import UIKit

class NSHomescreenViewController: NSTitleViewScrollViewController {
    // MARK: - Views

    private let infoBoxView = HomescreenInfoBoxView()
    private let handshakesModuleView = NSBegegnungenModuleView()
    private let meldungView = NSMeldungView()

    private let whatToDoSymptomsButton = NSWhatToDoButton(title: "whattodo_title_symptoms".ub_localized, subtitle: "whattodo_subtitle_symptoms".ub_localized, image: UIImage(named: "illu-symptome"))

    private let whatToDoPositiveTestButton = NSWhatToDoButton(title: "whattodo_title_positivetest".ub_localized, subtitle: "whattodo_subtitle_positivetest".ub_localized, image: UIImage(named: "illu-positiv-getestet"))

    private let syncronizeButton = NSButton(title: "refresh_database_button".ub_localized, style: .uppercase(.ns_purple))
    private let syncronizeContainerView = UIStackView()

    private let debugScreenButton = NSButton(title: "debug_settings_title".ub_localized, style: .outlineUppercase(.ns_red))

    private var lastState: UIStateModel = .init()

    private let appTitleView = NSAppTitleView()

    // MARK: - View

    override init() {
        super.init()

        titleView = appTitleView
        title = "app_name".ub_localized

        tabBarItem.image = UIImage(named: "ic-tracing")
        tabBarItem.title = "tab_tracing_title".ub_localized

        // always load view at init, even if app starts at meldungen detail
        loadViewIfNeeded()
    }

    // MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ns_backgroundSecondary

        setupLayout()

        meldungView.touchUpCallback = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.presentMeldungenDetail()
        }

        UIStateManager.shared.addObserver(self, block: { [weak self] state in
            guard let strongSelf = self else { return }
            strongSelf.updateState(state)
        })

        handshakesModuleView.touchUpCallback = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.presentBegegnungenDetail()
        }

        whatToDoPositiveTestButton.touchUpCallback = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.presentWhatToDoPositiveTest()
        }

        whatToDoSymptomsButton.touchUpCallback = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.presentWhatToDoSymptoms()
        }
        
        syncronizeButton.touchUpCallback = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.syncronizeDB()
        }
        
        // Ensure that Screen builds without animation if app not started on homescreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.finishTransition?()
            self.finishTransition = nil
        }
        
        NotificationCenter.default.addObserver(forName: Notification.Name("languageChangeNotification"),
                                               object: nil,
                                               queue: .main) { [weak self] _ in
                                                self?.localizeUI()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        presentOnboardingIfNeeded()
        
        appTitleView.changeBackgroundRandomly()
        UIStateManager.shared.refresh()

        if !UserStorage.shared.hasCompletedOnboarding {
            let v = UIView()
            v.backgroundColor = .ns_background
            view.addSubview(v)
            v.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                UIView.animate(withDuration: 0.5) {
                    v.alpha = 0.0
                    v.isUserInteractionEnabled = false
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        finishTransition?()
        finishTransition = nil

    }

    private var finishTransition: (() -> Void)?

    // MARK: - Setup

    private func setupLayout() {
        // navigation bar
        let infoImage = UIImage(named: "ic-info-outline")
        let languageImage = UIImage(named: "ic-language")
        
        let infoItem = UIBarButtonItem(image: infoImage, landscapeImagePhone: infoImage, style: .plain, target: self, action: #selector(infoButtonPressed))
        let languageItem = UIBarButtonItem(image: languageImage, landscapeImagePhone: languageImage, style: .plain, target: self, action: #selector(languageButtonPressed))
        
        infoItem.tintColor = .customPrimaryColor
        infoItem.accessibilityLabel = "accessibility_info_button".ub_localized
        
        languageItem.tintColor = .customPrimaryColor
        languageItem.accessibilityLabel = "accessibility_changeLanguage_button".ub_localized
        
        navigationItem.rightBarButtonItems = [languageItem, infoItem]

        // other views
        stackScrollView.addArrangedView(infoBoxView)

        stackScrollView.addArrangedView(handshakesModuleView)
        stackScrollView.addSpacerView(NSPadding.large)

        stackScrollView.addArrangedView(meldungView)
        stackScrollView.addSpacerView(2.0 * NSPadding.large)

        stackScrollView.addArrangedView(whatToDoSymptomsButton)
        stackScrollView.addSpacerView(NSPadding.large + NSPadding.medium)
        stackScrollView.addArrangedView(whatToDoPositiveTestButton)
        stackScrollView.addSpacerView(2.0 * NSPadding.large)
        
        if lastState.homescreen.meldungen.meldung != .infected {
            syncronizeContainerView.addSpacerView(2*NSPadding.medium)
            syncronizeContainerView.addArrangedView(syncronizeButton)
            syncronizeContainerView.addSpacerView(2*NSPadding.medium)
            syncronizeContainerView.alignment = .center
            syncronizeContainerView.axis = .horizontal
            
            stackScrollView.addArrangedView(syncronizeContainerView)
            stackScrollView.addSpacerView(2.0 * NSPadding.large)
        }

        #if ENABLE_TESTING

        let previewWarning = NSInfoBoxView(title: "preview_warning_title".ub_localized, subText: "preview_warning_text".ub_localized, image: UIImage(named: "ic-error")!, titleColor: .gray, subtextColor: .gray, leadingIconRenderingMode: .alwaysOriginal)
        stackScrollView.addArrangedView(previewWarning)

        stackScrollView.addSpacerView(NSPadding.large)

        let debugScreenContainer = UIView()

            if Environment.current != Environment.prod {
                debugScreenContainer.addSubview(debugScreenButton)
                debugScreenButton.snp.makeConstraints { make in
                    make.left.right.lessThanOrEqualToSuperview().inset(NSPadding.medium)
                    make.top.bottom.centerX.equalToSuperview()
                }

                debugScreenButton.touchUpCallback = { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.presentDebugScreen()
                }

                stackScrollView.addArrangedView(debugScreenContainer)

                stackScrollView.addSpacerView(NSPadding.large)
            }

        // DEBUG version for testing
        let uploadDBContainer = UIView()
        uploadDBContainer.addSubview(uploadDBButton)
        uploadDBButton.snp.makeConstraints { make in
            make.left.right.lessThanOrEqualToSuperview().inset(NSPadding.medium)
            make.top.bottom.centerX.equalToSuperview()
        }

        uploadDBButton.touchUpCallback = { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.uploadDatabaseForDebugPurposes()
        }

        stackScrollView.addArrangedView(uploadDBContainer)

        stackScrollView.addSpacerView(NSPadding.large)

        debugScreenContainer.alpha = 0
        uploadDBContainer.alpha = 0
        #endif
        // End DEBUG version for testing

        handshakesModuleView.alpha = 0
        meldungView.alpha = 0
        whatToDoSymptomsButton.alpha = 0
        whatToDoPositiveTestButton.alpha = 0

        finishTransition = {
            UIView.animate(withDuration: 0.8, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [.allowUserInteraction], animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)

            UIView.animate(withDuration: 0.3, delay: 0.35, options: [.allowUserInteraction], animations: {
                self.handshakesModuleView.alpha = 1
            }, completion: nil)

            UIView.animate(withDuration: 0.3, delay: 0.5, options: [.allowUserInteraction], animations: {
                self.meldungView.alpha = 1
            }, completion: nil)

            UIView.animate(withDuration: 0.3, delay: 0.65, options: [.allowUserInteraction], animations: {
                self.whatToDoSymptomsButton.alpha = 1
            }, completion: nil)

            UIView.animate(withDuration: 0.3, delay: 0.7, options: [.allowUserInteraction], animations: {
                self.whatToDoPositiveTestButton.alpha = 1
            }, completion: nil)

            #if ENABLE_TESTING
            UIView.animate(withDuration: 0.3, delay: 0.7, options: [.allowUserInteraction], animations: {
                debugScreenContainer.alpha = 1
            }, completion: nil)

            UIView.animate(withDuration: 0.3, delay: 0.7, options: [.allowUserInteraction], animations: {
                uploadDBContainer.alpha = 1
            }, completion: nil)
            #endif
        }
    }
    
    func localizeUI() {
        
        title = "app_name".ub_localized
        
        handshakesModuleView.localizeUI()
        meldungView.localizeUI()
        
        whatToDoSymptomsButton.titleString = "whattodo_title_symptoms".ub_localized
        whatToDoSymptomsButton.subtitleString = "whattodo_subtitle_symptoms".ub_localized
        
        whatToDoPositiveTestButton.titleString = "whattodo_title_positivetest".ub_localized
        whatToDoPositiveTestButton.subtitleString = "whattodo_subtitle_positivetest".ub_localized
        
        view.layoutSubviews()
                
    }

    func updateState(_ state: UIStateModel) {
        appTitleView.uiState = state.homescreen.header
        handshakesModuleView.uiState = state.homescreen.begegnungen
        meldungView.uiState = state.homescreen.meldungen

        let isInfected = state.homescreen.meldungen.meldung == .infected
        whatToDoSymptomsButton.isHidden = isInfected
        whatToDoPositiveTestButton.isHidden = isInfected

        infoBoxView.uiState = state.homescreen.infoBox
        infoBoxView.isHidden = state.homescreen.infoBox == nil

        if isInfected {
            stackScrollView.removeView(syncronizeContainerView)
        }
        
        lastState = state
    }

    // MARK: - Details

    private func presentOnboardingIfNeeded() {
        if !UserStorage.shared.hasCompletedOnboarding {
            let onboardingViewController = NSOnboardingViewController()
            onboardingViewController.modalPresentationStyle = .fullScreen
            present(onboardingViewController, animated: false)
        }
    }

    private func presentBegegnungenDetail() {
        navigationController?.pushViewController(NSBegegnungenDetailViewController(initialState: lastState.begegnungenDetail), animated: true)
    }

    func presentMeldungenDetail(animated: Bool = true) {
        navigationController?.pushViewController(NSMeldungenDetailViewController(), animated: animated)
    }

    #if ENABLE_TESTING
    private func presentDebugScreen() {
        navigationController?.pushViewController(NSDebugscreenViewController(), animated: true)
    }
    #endif

    private func presentWhatToDoPositiveTest() {
        navigationController?.pushViewController(NSWhatToDoPositiveTestViewController(), animated: true)
    }

    private func presentWhatToDoSymptoms() {
        navigationController?.pushViewController(NSWhatToDoSymptomViewController(), animated: true)
    }

    @objc private func infoButtonPressed() {
        present(NSNavigationController(rootViewController: NSAboutViewController()), animated: true)
    }
    
    @objc private func languageButtonPressed() {
        present(NSNavigationController(rootViewController: ChangeLanguageViewController()), animated: true)
    }
    
    private func syncronizeDB() {
        print("syncornizeDB")
        self.startLoading(withAlpha: 0.9)

        DatabaseSyncer.shared.forceSyncDatabase(manually: true) { (result) in
            self.stopLoading()
            var title: String
            var message: String
            switch result{
            case .failed:
                title = "refresh_database_failure_title".ub_localized
                message = "refresh_database_failure_message".ub_localized
                print("Failed: \(result)")
            default:
                title = "refresh_database_success_title".ub_localized
                message = "refresh_database_success_message".ub_localized
                print("Success: \(result)")
            }
            
            let loading = UIAlertController(title: title, message: message, preferredStyle: .alert)
            self.present(loading, animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                loading.dismiss(animated: true, completion: nil)
            }
        }
    }

    private let uploadDBButton = NSButton(title: "Upload DB to server", style: .outlineUppercase(.ns_red))
    private let uploadHelper = NSDebugDatabaseUploadHelper()
    private func uploadDatabaseForDebugPurposes() {
        let alert = UIAlertController(title: "Username", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = "" }
        alert.addAction(UIAlertAction(title: "Upload", style: .default, handler: { [weak alert, weak self] _ in
            let username = alert?.textFields?.first?.text ?? ""
            self?.uploadDB(with: username)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func uploadDB(with username: String) {
        let loading = UIAlertController(title: "Uploading...", message: "Please wait", preferredStyle: .alert)
        present(loading, animated: true)

        uploadHelper.uploadDatabase(username: username) { result in
            let alert: UIAlertController
            switch result {
            case .success:
                alert = UIAlertController(title: "Upload successful", message: nil, preferredStyle: .alert)
            case let .failure(error):
                alert = UIAlertController(title: "Upload failed", message: error.message, preferredStyle: .alert)
            }

            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            loading.dismiss(animated: false) {
                self.present(alert, animated: false)
            }
        }
    }
}
