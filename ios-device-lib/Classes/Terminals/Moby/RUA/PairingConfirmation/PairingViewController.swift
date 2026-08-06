//
//  PairingViewController.swift
//  ios-device-lib
//

import UIKit
import os.log

// MARK: - PairingViewController

class PairingViewController: UIViewController {

    // MARK: Properties (from header)

    var selectedDevice: RUADevice!
    weak var delegate: ConnectionListener?

    // MARK: Outlets (from private extension)

    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var ledPairingViewContainer: UIView!
    @IBOutlet private weak var ledSequenceContainer: UIImageView!
    @IBOutlet private weak var pairingStatus: UILabel!
    @IBOutlet private weak var spinner: UIActivityIndicatorView!
    @IBOutlet private weak var pairButton: UIButton!
    @IBOutlet private weak var disconnectButton: UIButton!

    // MARK: Private stored properties

    private var ledPairingView: RUALedPairingView!
    private var ledConfirmationCb: RUALedPairingConfirmationCallback?

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let device = selectedDevice else {
            os_log("[PairingVC] selectedDevice is nil — dismissing")
            dismiss(animated: false, completion: nil)
            return
        }

        statusLabel.text = "Not Connected"
        statusLabel.textColor = .red
        nameLabel.text = device.name

        let containerFrame = ledSequenceContainer.frame
        let width = containerFrame.width / 3
        let height = containerFrame.width / 12 // matches original aspect ratio
        let x = containerFrame.width / 3
        let y = containerFrame.height / 9
        ledPairingView = RUALedPairingView(frame: CGRect(x: x, y: y, width: width, height: height))
        ledSequenceContainer.addSubview(ledPairingView)

        hidePairingView()
        pairingStatus.isHidden = true
        pairButton.isHidden = false
        disconnectButton.isHidden = true
    }

    // MARK: Public methods (from header)

    func showPairingView(sequences: [Any]) {
        pairButton.isHidden = true
        ledPairingViewContainer.isHidden = false
        ledPairingViewContainer.isUserInteractionEnabled = true
        ledPairingView.showSequences(sequences)
    }

    func setLedConfirmationCB(_ ledConfirmationCb: RUALedPairingConfirmationCallback) {
        self.ledConfirmationCb = ledConfirmationCb
    }

    // MARK: Private helpers

    private func hidePairingView() {
        ledPairingViewContainer.isHidden = true
        ledPairingViewContainer.isUserInteractionEnabled = false
    }

    // MARK: IBActions

    @IBAction func pairReader(_ sender: Any) {
        pairingStatus.isHidden = true
        // Original code passed "self" as device; corrected to use selectedDevice.
        RUA.getDeviceManager(RUADeviceTypeMOBY5500)?.initializeDevice(self, pairingListener: self)
        pairButton.isHidden = true
    }

    @IBAction func confirmPairing(_ sender: Any) {
        ledConfirmationCb?.confirm()
        hidePairingView()
        spinner.startAnimating()
        pairingStatus.text = "Pairing..."
        pairingStatus.isHidden = false
        pairingStatus.textColor = .black
        dismiss(animated: true, completion: nil)
    }

    @IBAction func cancelPairing(_ sender: Any) {
        ledConfirmationCb?.cancel()
    }

    @IBAction func restartPairing(_ sender: Any) {
        ledConfirmationCb?.restartLedPairingSequence()
    }

    @IBAction func disconnect(_ sender: Any) {
        RUA.getDeviceManager(RUADeviceTypeMOBY5500)?.releaseDevice()
    }

    @IBAction func close(_ sender: Any) {
        dismiss(animated: true) {
            print("REMOVING")
        }
    }
}

// MARK: - RUADeviceStatusHandler

extension PairingViewController: RUADeviceStatusHandler {

    func onConnected() {
        statusLabel.text = "Connected"
        statusLabel.textColor = .green
        disconnectButton.isHidden = false
        delegate?.onDeviceConnected()
        dismiss(animated: true, completion: nil)
    }

    func onDisconnected() {
        statusLabel.text = "Not Connected"
        statusLabel.textColor = .red
        pairButton.isHidden = false
        disconnectButton.isHidden = true
        delegate?.onDeviceConnectionCancelled()
    }

    func onError(_ message: String) {
        statusLabel.text = message
        statusLabel.textColor = .red
        pairButton.isHidden = false
        disconnectButton.isHidden = true
        delegate?.onDeviceConnectionFailed()
    }
}

// MARK: - RUAPairingListener

extension PairingViewController: RUAPairingListener {

    func onPairSucceeded() {
        spinner.stopAnimating()
        pairingStatus.text = "Pairing Success!"
        pairingStatus.isHidden = false
        pairingStatus.textColor = .green
        delegate?.onDeviceConnected()
        dismiss(animated: true, completion: nil)
    }

    func onPairNotSupported() {
        hidePairingView()
        pairingStatus.text = "Pairing Not Supported!"
        pairingStatus.isHidden = false
        pairingStatus.textColor = .red
        pairButton.isHidden = false
        delegate?.onDeviceConnectionFailed()
    }

    func onPairFailed() {
        spinner.stopAnimating()
        hidePairingView()
        pairingStatus.text = "Pairing Failed!"
        pairingStatus.isHidden = false
        pairingStatus.textColor = .red
        pairButton.isHidden = false
        delegate?.onDeviceConnectionFailed()
    }

    func onPairCancelled() {
        spinner.stopAnimating()
        hidePairingView()
        pairingStatus.text = "Pairing Cancelled!"
        pairingStatus.isHidden = false
        pairingStatus.textColor = .red
        pairButton.isHidden = false
        delegate?.onDeviceConnectionCancelled()
    }

    func onLedPairSequenceConfirmation(_ ledSequence: [Any], confirmationCallback: RUALedPairingConfirmationCallback) {
        ledConfirmationCb = confirmationCallback
        showPairingView(sequences: ledSequence)
    }
}
