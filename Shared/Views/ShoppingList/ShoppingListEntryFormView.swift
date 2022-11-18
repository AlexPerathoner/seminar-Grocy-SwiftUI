//
//  ShoppingListEntryFormView.swift
//  Grocy-SwiftUI
//
//  Created by Georg Meissner on 02.12.20.
//

import SwiftUI

struct ShoppingListEntryFormView: View {
    @StateObject var grocyVM: GrocyViewModel = .shared
    
    @Environment(\.dismiss) var dismiss
    
    @State private var firstAppear: Bool = true
    
    @State private var shoppingListID: Int = 1
    @State private var productID: Int?
    @State private var amount: Double = 1.0
    @State private var quantityUnitID: Int?
    @State private var note: String = ""
    
    @State private var showFailToast: Bool = false
    
    var isNewShoppingListEntry: Bool
    var shoppingListEntry: ShoppingListItem?
    var selectedShoppingListID: Int?
    var productIDToSelect: Int?
    var isPopup: Bool = false
    
    var isFormValid: Bool {
        return amount > 0
    }
    
    var product: MDProduct? {
        grocyVM.mdProducts.first(where: {$0.id == productID})
    }
    
    private func getQuantityUnit() -> MDQuantityUnit? {
        let quIDP = grocyVM.mdProducts.first(where: {$0.id == productID})?.quIDPurchase
        let qu = grocyVM.mdQuantityUnits.first(where: {$0.id == quIDP})
        return qu
    }
    private var currentQuantityUnit: MDQuantityUnit? {
        let quIDP = grocyVM.mdProducts.first(where: {$0.id == productID})?.quIDPurchase
        return grocyVM.mdQuantityUnits.first(where: {$0.id == quIDP})
    }
    
    private func updateData() {
        grocyVM.requestData(objects: [.shopping_list])
    }
    
    private func finishForm() {
#if os(iOS)
        self.dismiss()
#elseif os(macOS)
        NSApp.sendAction(#selector(NSPopover.performClose(_:)), to: nil, from: nil)
#endif
    }
    
    func saveShoppingListEntry() {
        let factoredAmount = amount * (product?.quFactorPurchaseToStock ?? 1.0)
        if isNewShoppingListEntry{
            grocyVM.addShoppingListItem(content: ShoppingListItemAdd(amount: factoredAmount, note: note, productID: productID, quID: quantityUnitID, shoppingListID: shoppingListID), completion: { result in
                switch result {
                case let .success(message):
                    grocyVM.postLog("Shopping list entry saved successfully. \(message)", type: .info)
                    updateData()
                    finishForm()
                case let .failure(error):
                    grocyVM.postLog("Shopping list entry save failed. \(error)", type: .error)
                    showFailToast = true
                }
            })
        } else {
            if let entry = shoppingListEntry {
                grocyVM.putMDObjectWithID(object: .shopping_list, id: entry.id, content: ShoppingListItem(id: entry.id, productID: productID, note: note, amount: factoredAmount, shoppingListID: entry.shoppingListID, done: entry.done, quID: entry.quID, rowCreatedTimestamp: entry.rowCreatedTimestamp), completion: { result in
                    switch result {
                    case let .success(message):
                        grocyVM.postLog("Shopping entry edited successfully. \(message)", type: .info)
                        updateData()
                        finishForm()
                    case let .failure(error):
                        grocyVM.postLog("Shopping entry edit failed. \(error)", type: .error)
                        showFailToast = true
                    }
                })
            }
        }
    }
    
    private func resetForm() {
        self.shoppingListID = shoppingListEntry?.shoppingListID ?? selectedShoppingListID ?? 1
        self.productID = shoppingListEntry?.productID ?? product?.id
        self.amount = (shoppingListEntry?.amount ?? (product != nil ? 1.0 : 0.0)) / (product?.quFactorPurchaseToStock ?? 1.0)
        self.quantityUnitID = shoppingListEntry?.quID ?? product?.quIDPurchase
        self.note = shoppingListEntry?.note ?? ""
    }
    
    var body: some View {
        content
            .navigationTitle(isNewShoppingListEntry ? LocalizedStringKey("str.shL.entryForm.new.title") : LocalizedStringKey("str.shL.entryForm.edit.title"))
            .toolbar{
                ToolbarItem(placement: .cancellationAction) {
                    if isNewShoppingListEntry {
                        Button(LocalizedStringKey("str.cancel"), role: .cancel, action: finishForm)
                            .keyboardShortcut(.cancelAction)
                    }
                }
#if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("str.save")) {
                        saveShoppingListEntry()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid)
                }
#endif
            }
    }
    
    var content: some View {
        Form {
#if os(macOS)
            Text(isNewShoppingListEntry ? LocalizedStringKey("str.shL.entryForm.new.title") : LocalizedStringKey("str.shL.entryForm.edit.title")).font(.headline)
#endif
            Picker(selection: $shoppingListID, label: Text(LocalizedStringKey("str.shL.entryForm.shoppingList")), content: {
                ForEach(grocyVM.shoppingListDescriptions, id:\.id) { shLDescription in
                    Text(shLDescription.name).tag(shLDescription.id)
                }
            })
            
            ProductField(productID: $productID, description: "str.shL.entryForm.product")
                .onChange(of: productID) { newProduct in
                    if let selectedProduct = grocyVM.mdProducts.first(where: {$0.id == productID}) {
                        quantityUnitID = selectedProduct.quIDPurchase
                    }
                }
            
            AmountSelectionView(productID: $productID, amount: $amount, quantityUnitID: $quantityUnitID)
            
            Section(header: Label(LocalizedStringKey("str.shL.entryForm.note"), systemImage: "square.and.pencil")
                .labelStyle(.titleAndIcon)
                .font(.headline))
            {
                TextEditor(text: $note)
                    .frame(height: 50)
            }
#if os(macOS)
            HStack{
                Button(LocalizedStringKey("str.cancel")) {
                    finishForm()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(LocalizedStringKey("str.save")) {
                    saveShoppingListEntry()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
#endif
        }
        .onAppear(perform: {
            if firstAppear {
                grocyVM.requestData(objects: [.shopping_list])
                resetForm()
                firstAppear = false
            }
        })
        .toast(isPresented: $showFailToast, isSuccess: false, text: LocalizedStringKey("str.shL.entryForm.save.failed"))
    }
}

struct ShoppingListEntryFormView_Previews: PreviewProvider {
    static var previews: some View {
        ShoppingListEntryFormView(isNewShoppingListEntry: true)
    }
}
