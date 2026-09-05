package de.kamilunavo.arbeitsklar

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.*
import kotlinx.coroutines.flow.MutableStateFlow

data class BillingState(val ready:Boolean=false,val pro:Boolean=false,val product:ProductDetails?=null)

class BillingManager(context:Context) {
    companion object { const val PRO="de.kamilunavo.arbeitsklar.pro.lifetime" }
    val state=MutableStateFlow(BillingState())
    private lateinit var client:BillingClient
    init {
        client=BillingClient.newBuilder(context)
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .setListener{result,purchases->
                if(result.responseCode==BillingClient.BillingResponseCode.OK) purchases.orEmpty().forEach{p->
                    if(p.purchaseState==Purchase.PurchaseState.PURCHASED){
                        state.value=state.value.copy(pro=true)
                        if(!p.isAcknowledged)client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.purchaseToken).build()){}
                    }
                }
            }.build()
        client.startConnection(object:BillingClientStateListener{
            override fun onBillingServiceDisconnected(){state.value=state.value.copy(ready=false)}
            override fun onBillingSetupFinished(result:BillingResult){if(result.responseCode==BillingClient.BillingResponseCode.OK){state.value=state.value.copy(ready=true);load();restore()}}
        })
    }
    private fun load(){
        val item=QueryProductDetailsParams.Product.newBuilder().setProductId(PRO).setProductType(BillingClient.ProductType.INAPP).build()
        client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(listOf(item)).build()){r,p->
            if(r.responseCode==BillingClient.BillingResponseCode.OK)state.value=state.value.copy(product=p.productDetailsList.firstOrNull())
        }
    }
    fun purchase(activity:Activity){val p=state.value.product?:return;client.launchBillingFlow(activity,BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(p).build())).build())}
    fun restore(){client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()){_,p->state.value=state.value.copy(pro=p.any{it.purchaseState==Purchase.PurchaseState.PURCHASED})}}
}
