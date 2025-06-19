// Licensed under the Any Distance Source-Available License
//
//  ShareViewController.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/31/20.
//

import UIKit
import ScalingCarousel
import Photos
import Social
import PureLayout
import MessageUI
import Combine

protocol ShareViewControllerDelegate: AnyObject {
    func showReviewPromptIfNecessary()
    func addToPost(_ image: UIImage)
    func addToPost(_ videoUrl: URL)
}

/// View controller that allows sharing assets to social media in the form of ShareImages or ShareVideos
class ShareViewController: VisualGeneratingViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var carousel: ScalingCarouselView?
    @IBOutlet weak var imagePreviewLabel: UILabel!
    @IBOutlet weak var pageControl: UIPageControl?
    @IBOutlet weak var addBackgroundPhotoButton: UIButton?
    @IBOutlet weak var addBackgroundPhotoButtonHeightConstraint: NSLayoutConstraint?
    @IBOutlet weak var addToPostButton: ContinuousCornerButton?
    
    @IBOutlet weak var instagramButton: UIButton!
    @IBOutlet weak var twitterButton: UIButton!
    @IBOutlet weak var messagesButton: UIButton!
    @IBOutlet weak var saveToPhotosButton: LoadingButton!
    @IBOutlet weak var moreOptionsButton: UIButton!
    
    // MARK: - Variables
    
    weak var delegate: ShareViewControllerDelegate?
    var images: ShareImages?
    var videos: ShareVideos?
    var pageIdx = 0
    var showsAddToPostButton: Bool = false
    var showsAddBackgroundPhotoButton: Bool = false
    var addBackgroundPhotoAction: (() -> Void)?
    private var disposables = Set<AnyCancellable>()

    var screenName: String {
        return "Share"
    }
    
    private var shareButtonsEnabled: Bool = true {
        didSet {
            let buttons = [
                instagramButton,
                twitterButton,
                messagesButton,
                saveToPhotosButton,
                moreOptionsButton
            ]
            buttons.forEach { button in
                button?.isEnabled = shareButtonsEnabled
            }
            saveToPhotosButton.alpha = shareButtonsEnabled ? 1.0 : 0.7
            moreOptionsButton.alpha = shareButtonsEnabled ? 1.0 : 0.7
        }
    }
    
    var currentImage: UIImage? {
        return images?.image(forPageIdx: pageIdx)
    }
    
    var currentVideoUrl: URL? {
        return videos?.videoUrl(forPageIdx: pageIdx)
    }
    
    // MARK: - Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        Analytics.logEvent(screenName, screenName, .screenViewed)
    }
    
    func setup() {
        carousel?.reloadData()
        carousel?.isPagingEnabled = true
        titleLabel?.text = title
        addToPostButton?.isHidden = !showsAddToPostButton
        addBackgroundPhotoButtonHeightConstraint?.constant = showsAddBackgroundPhotoButton ? 44 : 0
        addBackgroundPhotoButton?.isHidden = !showsAddBackgroundPhotoButton
        
        if let videos = videos {
            pageControl?.numberOfPages = videos.numberOfItems
            if videos.numberOfItems == 1 {
                pageControl?.isHidden = true
            }
        } else {
            pageControl?.numberOfPages = 3
        }
    }
    
    // MARK: - Actions
    
    @IBAction func cancelTapped(_ sender: Any) {
        dismiss(animated: true) { [weak self] in
            self?.delegate?.showReviewPromptIfNecessary()
        }
        Analytics.logEvent("Cancel", screenName, .buttonTap)
    }

    @IBAction func addBackgroundPhotoTapped(_ sender: Any) {
        addBackgroundPhotoAction?()
    }

    @IBAction func saveToPhotosTapped(_ sender: Any) {
        Analytics.logEvent("Save to Photos", screenName, .buttonTap)
        
        func completion(_ success: Bool, _ error: Error?) {
            saveToPhotosButton.isLoading = false
            guard success && error == nil else {
                showPhotoSavingError(error)
                return
            }
            
            Analytics.logEvent("Saved to Photos Successfully", screenName, .otherEvent)
            let alert = UIAlertController(title: "Saved to Photos!", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Open Photos", style: .default, handler: { _ in
                UIApplication.shared.open(URL(string:"photos-redirect://")!)
            }))
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }

        saveToPhotosButton.isLoading = true
        let screenName = self.screenName
        if let image = currentImage {
            PhotoLibrarySaver.saveImage(image) { (success, _, error) in
                completion(success, error)
            }
        } else if let videoUrl = currentVideoUrl {
            PhotoLibrarySaver.saveVideo(videoUrl) { (success, _, error) in
                completion(success, error)
            }
        }
    }
    
    @IBAction func addToPostTapped(_ sender: Any) {
        if let images = images {
            delegate?.addToPost(images.base)
        } else if let videoUrl = videos?.noWatermarkInstagramStoryUrl {
            delegate?.addToPost(videoUrl)
        }
    }
    
    @IBAction func shareToTwitterTapped(_ sender: Any) {
        Analytics.logEvent("Share to Twitter", screenName, .buttonTap)
        
        let twitterUrl = URL(string: "twitter://")!
        guard UIApplication.shared.canOpenURL(twitterUrl) else {
            showTwitterError()
            return
        }
        
        func completion(_ success: Bool, _ error: Error?) {
            guard success && error == nil else {
                self.showPhotoSavingError(error)
                return
            }
            
            let alert = UIAlertController(title: "Image saved to Photos. Open Twitter to start a new tweet and add the image.", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            alert.addAction(UIAlertAction(title: "Open Twitter", style: .default, handler: { (action) in
                UIApplication.shared.open(twitterUrl, options: [:], completionHandler: nil)
            }))
            self.present(alert, animated: true, completion: nil)
        }
        
        if let image = images?.twitter ?? images?.instagramFeed ?? images?.instagramStory {
            PhotoLibrarySaver.saveImage(image) { (success, _, error) in
                completion(success, error)
            }
        } else if let videoUrl = videos?.squareUrl ?? videos?.instagramStoryUrl {
            PhotoLibrarySaver.saveVideo(videoUrl) { (success, _, error) in
                completion(success, error)
            }
        }
    }
    
    func showPhotoSavingError(_ error: Error?) {
        let alert = UIAlertController.defaultWith(title: "Could not save to photos.", message: "")
        self.present(alert, animated: true, completion: nil)
        Analytics.logEvent("Error Saving to Photos",
                           screenName,
                           .otherEvent,
                           withParameters: ["error" : error?.localizedDescription ?? ""])
    }
    
    @IBAction func shareToInstagramTapped(_ sender: Any) {
        Analytics.logEvent("Share to Instagram", screenName, .buttonTap)
        
        let alert = UIAlertController(title: "Where are you sharing to?", message: nil, preferredStyle: .alert)
        let screenName = self.screenName
        let storiesAction = UIAlertAction(title: "Stories", style: .default) { [weak self] (action) in
            self?.shareToInstagramStory()
            Analytics.logEvent("Share to Story", screenName, .buttonTap)
        }
        
        let feedAction = UIAlertAction(title: "Feed Post", style: .default) { [weak self] (action) in
            self?.shareToInstagramFeed()
            Analytics.logEvent("Share to Feed", screenName, .buttonTap)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)
        alert.addActions([storiesAction, feedAction, cancelAction])
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func shareToMessagesTapped(_ sender: Any) {
        Analytics.logEvent("Share to Messages", screenName, .buttonTap)
        
        let composeController = MFMessageComposeViewController()
        composeController.messageComposeDelegate = self
        if let imageData = currentImage?.pngData() {
            composeController.addAttachmentData(imageData, typeIdentifier: "public.png", filename: "Share-Image.png")
        } else if let videoUrl = currentVideoUrl {
            composeController.addAttachmentURL(videoUrl, withAlternateFilename: nil)
        }
        
        present(composeController, animated: true, completion: nil)
    }
    
    @IBAction func shareAsSnapTapped(_ sender: Any) {
        Analytics.logEvent("Share to Snap", screenName, .buttonTap)
        
        let urlScheme = URL(string: "snapchat://creativekit/preview/1")!
        guard UIApplication.shared.canOpenURL(urlScheme) else {
            return
        }
        
        if let image = images?.instagramStory,
           let pngData = image.pngData() {
            let items: [[String : Any]] = [["com.snapchat.creativekit.clientID" : "",
                                            "com.snapchat.creativekit.backgroundImage" : pngData,
                                            "com.snapchat.creativekit.attachmentURL" : "http://anydistance.club/",
                                            "com.snapchat.creativekit.appName" : "Any Distance"]]
            UIPasteboard.general.setItems(items, options: [:])
            UIApplication.shared.open(urlScheme, options: [:], completionHandler: nil)
        } else if let videoUrl = videos?.instagramStoryUrl,
                  let videoData = try? Data(contentsOf: videoUrl) {
            let items: [[String : Any]] = [["com.snapchat.creativekit.clientID" : "",
                                            "com.snapchat.creativekit.backgroundVideo" : videoData,
                                            "com.snapchat.creativekit.attachmentURL" : "http://anydistance.club/",
                                            "com.snapchat.creativekit.appName" : "Any Distance"]]
            UIPasteboard.general.setItems(items, options: [:])
            UIApplication.shared.open(urlScheme, options: [:], completionHandler: nil)
        } else {
            showSnapError()
        }
    }
    
    private func shareToInstagramStory() {
        if let image = images?.instagramStory,
           let pngData = image.pngData() {
            let urlScheme = URL(string: "instagram-stories://share?source_application=")!
            if UIApplication.shared.canOpenURL(urlScheme) {
                let items: [[String : Any]] = [["com.instagram.sharedSticker.backgroundImage" : pngData]]
                UIPasteboard.general.setItems(items, options: [:])
                UIApplication.shared.open(urlScheme, options: [:], completionHandler: nil)
            }
        } else if let videoUrl = videos?.instagramStoryUrl,
                  let videoData = try? Data(contentsOf: videoUrl) {
            let urlScheme = URL(string: "instagram-stories://share?source_application=")!
            if UIApplication.shared.canOpenURL(urlScheme) {
                let items: [[String : Any]] = [["com.instagram.sharedSticker.backgroundVideo" : videoData]]
                UIPasteboard.general.setItems(items, options: [:])
                UIApplication.shared.open(urlScheme, options: [:], completionHandler: nil)
            }
        } else {
            showInstagramError()
        }
    }
    
    private func shareToInstagramFeed() {
        func completion(_ success: Bool, _ placeholder: PHObjectPlaceholder?, _ error: Error?) {
            guard success,
                  let placeholder = placeholder,
                  error == nil else {
                return
            }
            
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
            guard let asset = assets.firstObject else {
                return
            }
            
            asset.requestContentEditingInput(with: nil, completionHandler: { (editingInput, _) in
                let url = editingInput?.fullSizeImageURL ?? (editingInput?.audiovisualAsset as? AVURLAsset)?.url
                DispatchQueue.main.async {
                    if let path = url?.absoluteString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed) {
                        let instagram = URL(string: "instagram://library?AssetPath=\(path)")
                        UIApplication.shared.open(instagram!)
                    }
                }
            })
        }
        
        if let image = images?.instagramFeed {
            PhotoLibrarySaver.saveImage(image) { (success, placeholder, error) in
                completion(success, placeholder, error)
            }
        } else if let videoUrl = videos?.squareUrl {
            PhotoLibrarySaver.saveVideo(videoUrl) { (success, placeholder, error) in
                completion(success, placeholder, error)
            }
        }
    }
    
    private func showInstagramError() {
        let alert = UIAlertController.defaultWith(title: "To share to Instagram, you must have the Instagram app installed.", message: "")
        present(alert, animated: true, completion: nil)
        Analytics.logEvent("Instagram Error - App Not Installed", screenName, .otherEvent)
    }
    
    private func showTwitterError() {
        let alert = UIAlertController.defaultWith(title: "To share to Twitter, you must have the Twitter app installed.", message: "")
        present(alert, animated: true, completion: nil)
        Analytics.logEvent("Twitter Error - App Not Installed", screenName, .otherEvent)
    }
    
    private func showSnapError() {
        let alert = UIAlertController.defaultWith(title: "Looks like Snapchat is not installed right now.", message: "")
        present(alert, animated: true, completion: nil)
        Analytics.logEvent("Snapchat Error - App Not Installed", screenName, .otherEvent)
    }
    
    @IBAction func moreOptionsTapped(_ sender: Any) {
        Analytics.logEvent("More Options", screenName, .buttonTap)
        
        if let image = currentImage {
            let activityVC = UIActivityViewController(activityItems: [image],
                                                      applicationActivities: nil)
            present(activityVC, animated: true, completion: nil)
        } else if let video = currentVideoUrl {
            let activityVC = UIActivityViewController(activityItems: [video],
                                                      applicationActivities: nil)
            present(activityVC, animated: true, completion: nil)
        }
    }
}

extension ShareViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pageControl?.numberOfPages ?? 3
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ShareCarouselCell.reuseId,
                                                         for: indexPath) as? ShareCarouselCell {
            if let images = images {
                cell.setImage(images.image(forPageIdx: indexPath.row))
            } else if let videos = videos {
                let videoURL = videos.videoUrl(forPageIdx: indexPath.row)
                cell.setVideo(withUrl: videoURL)
                
                disposables.removeAll()
                
                if indexPath.item == 1 && videoURL == nil {
                    videos.$squareVideoProgress
                        .receive(on: DispatchQueue.main)
                        .sink(receiveValue: { progress in
                            cell.progressView?.setProgress(progress, animated: true)
                            cell.progressView?.isHidden = !(progress > 0.0 && progress < 1.0)
                        })
                        .store(in: &disposables)
                    
                    videos.$squareUrl
                        .receive(on: DispatchQueue.main)
                        .filter { $0 != nil }
                        .sink(receiveValue: { [weak self] _ in
                            self?.shareButtonsEnabled = true
                            cell.progressView?.isHidden = true
                            self?.carousel?.reloadItems(at: [indexPath])
                        })
                        .store(in: &disposables)
                }
                
            }
            
            return cell
        }
        
        return UICollectionViewCell()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let carousel = carousel else {
            return
        }
        
        carousel.didScroll()
        
        let carouselItemWidth = view.frame.width - (carousel.inset * 2)
        pageIdx = Int((scrollView.contentOffset.x + (carouselItemWidth / 2)) / carouselItemWidth)
        pageControl?.currentPage = pageIdx
        
        if let videos = videos {
            let videoURL = videos.videoUrl(forPageIdx: pageIdx)
            self.shareButtonsEnabled = videoURL != nil
        }
        
        let previewLabels = videos == nil ? ["Stories", "Twitter Feed", "Square"] : ["Stories", "Square"]
        if imagePreviewLabel.text != previewLabels[pageIdx] {
            UIView.transition(with: imagePreviewLabel, duration: 0.2, options: [.transitionCrossDissolve], animations: {
                self.imagePreviewLabel.text = previewLabels[self.pageIdx]
            }, completion: nil)
        }
    }
}

extension ShareViewController: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
        if result == .sent {
            Analytics.logEvent("iMessage Sent", screenName, .otherEvent)
        } else {
            Analytics.logEvent("iMessage Failed to Send", screenName, .otherEvent)
        }
    }
}

extension ShareViewController: UIDocumentInteractionControllerDelegate {}
