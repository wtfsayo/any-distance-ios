// Licensed under the Any Distance Source-Available License
//
//  SearchField.swift
//  ADAC
//
//  Created by Daniel Kuntz on 6/28/22.
//

import SwiftUI

struct SearchField: UIViewRepresentable {
    @Binding var text: String
    private var placeholder = ""

    init(text: Binding<String>) {
        _text = text
    }

    class Cordinator : NSObject, UISearchBarDelegate {
        @Binding var text : String

        init(text : Binding<String>) {
            _text = text
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
            text = ""
        }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            searchBar.setShowsCancelButton(true, animated: true)
        }

        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            searchBar.setShowsCancelButton(false, animated: true)
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }

    func makeCoordinator() -> SearchField.Cordinator {
        return Cordinator(text: $text)
    }

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        searchBar.searchTextField.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        searchBar.placeholder = placeholder
        searchBar.tintColor = .white
        searchBar.searchBarStyle = .minimal
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
        uiView.placeholder = placeholder
    }
}

extension SearchField {
    func placeholder(_ string: String) -> SearchField {
        var view = self
        view.placeholder = string
        return view
    }
}
