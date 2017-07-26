#!/bin/bash
# ----------------------------------------------------------------------------------------------
# Testing the smart contract
#
# Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2017. The MIT Licence.
# ----------------------------------------------------------------------------------------------

MODE=${1:-test}

GETHATTACHPOINT=`grep ^IPCFILE= settings.txt | sed "s/^.*=//"`
PASSWORD=`grep ^PASSWORD= settings.txt | sed "s/^.*=//"`

CONTRACTSDIR=`grep ^CONTRACTSDIR= settings.txt | sed "s/^.*=//"`

WALLETSOL=`grep ^WALLETSOL= settings.txt | sed "s/^.*=//"`
WALLETTEMPSOL=`grep ^WALLETTEMPSOL= settings.txt | sed "s/^.*=//"`
WALLETJS=`grep ^WALLETJS= settings.txt | sed "s/^.*=//"`

DEPLOYMENTDATA=`grep ^DEPLOYMENTDATA= settings.txt | sed "s/^.*=//"`

INCLUDEJS=`grep ^INCLUDEJS= settings.txt | sed "s/^.*=//"`
TEST1OUTPUT=`grep ^TEST1OUTPUT= settings.txt | sed "s/^.*=//"`
TEST1RESULTS=`grep ^TEST1RESULTS= settings.txt | sed "s/^.*=//"`

CURRENTTIME=`date +%s`
CURRENTTIMES=`date -r $CURRENTTIME -u`

BLOCKSINDAY=10

if [ "$MODE" == "dev" ]; then
  # Start time now
  STARTTIME=`echo "$CURRENTTIME" | bc`
else
  # Start time 1m 10s in the future
  STARTTIME=`echo "$CURRENTTIME+75" | bc`
fi
STARTTIME_S=`date -r $STARTTIME -u`
ENDTIME=`echo "$CURRENTTIME+60*3" | bc`
ENDTIME_S=`date -r $ENDTIME -u`

printf "MODE            = '$MODE'\n" | tee $TEST1OUTPUT
printf "GETHATTACHPOINT = '$GETHATTACHPOINT'\n" | tee -a $TEST1OUTPUT
printf "PASSWORD        = '$PASSWORD'\n" | tee -a $TEST1OUTPUT
printf "CONTRACTSDIR    = '$CONTRACTSDIR'\n" | tee -a $TEST1OUTPUT
printf "WALLETSOL       = '$WALLETSOL'\n" | tee -a $TEST1OUTPUT
printf "WALLETTEMPSOL   = '$WALLETTEMPSOL'\n" | tee -a $TEST1OUTPUT
printf "WALLETJS        = '$WALLETJS'\n" | tee -a $TEST1OUTPUT
printf "DEPLOYMENTDATA  = '$DEPLOYMENTDATA'\n" | tee -a $TEST1OUTPUT
printf "INCLUDEJS       = '$INCLUDEJS'\n" | tee -a $TEST1OUTPUT
printf "TEST1OUTPUT     = '$TEST1OUTPUT'\n" | tee -a $TEST1OUTPUT
printf "TEST1RESULTS    = '$TEST1RESULTS'\n" | tee -a $TEST1OUTPUT
printf "CURRENTTIME     = '$CURRENTTIME' '$CURRENTTIMES'\n" | tee -a $TEST1OUTPUT
printf "STARTTIME       = '$STARTTIME' '$STARTTIME_S'\n" | tee -a $TEST1OUTPUT
printf "ENDTIME         = '$ENDTIME' '$ENDTIME_S'\n" | tee -a $TEST1OUTPUT

# Make copy of SOL file and modify start and end times ---
`cp modifiedContracts/$WALLETSOL $WALLETTEMPSOL`

# --- Modify any parameters? ---
#`perl -pi -e "s/STARTDATE \= 1498741200;.*$/STARTDATE \= $STARTTIME; \/\/ $STARTTIME_S/" $DAOCASINOTOKENTEMPSOL`
#`perl -pi -e "s/ENDDATE \= STARTDATE \+ 28 days;.*$/ENDDATE \= STARTDATE \+ 5 minutes;/" $DAOCASINOTOKENTEMPSOL`
#`perl -pi -e "s/CAP \= 84417 ether;.*$/CAP \= 100 ether;/" $DAOCASINOTOKENTEMPSOL`

DIFFS1=`diff $CONTRACTSDIR/$WALLETSOL $WALLETTEMPSOL`
echo "--- Differences $CONTRACTSDIR/$WALLETSOL $WALLETTEMPSOL ---"
echo "$DIFFS1"

echo "var walletOutput=`solc --optimize --combined-json abi,bin,interface $WALLETTEMPSOL`;" > $WALLETJS

geth --verbosity 3 attach $GETHATTACHPOINT << EOF | tee -a $TEST1OUTPUT
loadScript("$WALLETJS");
loadScript("functions.js");

var walletAbi = JSON.parse(walletOutput.contracts["$WALLETTEMPSOL:MultiSigWallet"].abi);
var walletBin = "0x" + walletOutput.contracts["$WALLETTEMPSOL:MultiSigWallet"].bin;

console.log("DATA: walletAbi=" + JSON.stringify(walletAbi));

unlockAccounts("$PASSWORD");
printBalances();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var deployWalletMessage = "Deploy Wallet Contract - 2 Of 4 Signatures Required";
// -----------------------------------------------------------------------------
console.log("RESULT: " + deployWalletMessage);
var walletContract = web3.eth.contract(walletAbi);
console.log(JSON.stringify(walletContract));
var walletTx = null;
var walletAddress = null;

var dct = walletContract.new([multisigOwner1, multisigOwner2, multisigOwner3, multisigOwner4], 2, {from: contractOwnerAccount, data: walletBin, gas: 6000000},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        walletTx = contract.transactionHash;
      } else {
        walletAddress = contract.address;
        addAccount(walletAddress, "Wallet Contract");
        addWalletContractAddressAndAbi(walletAddress, walletAbi);
        console.log("DATA: walletAddress=" + walletAddress);
      }
    }
  }
);

while (txpool.status.pending > 0) {
}

printTxData("walletAddress=" + walletAddress, walletTx);
printBalances();
failIfGasEqualsGasUsed(walletTx, deployWalletMessage);
printWalletContractDetails();
console.log("RESULT: ");

exit;

// -----------------------------------------------------------------------------
var fillMessage = "Fill Token Balances";
// -----------------------------------------------------------------------------
console.log("RESULT: " + fillMessage);
var D160 = new BigNumber("10000000000000000000000000000000000000000", 16);
var balances = [];
var amount = new BigNumber("100000").shift(18);
var addressNum = new BigNumber(account3.substring(2), 16);
var v = D160.mul(amount).add(addressNum);
balances.push(v.toString(10));
amount = new BigNumber("10000").shift(18);
addressNum = new BigNumber(account4.substring(2), 16);
v = D160.mul(amount).add(addressNum);
balances.push(v.toString(10));
var fillTx = dct.fill(balances, {from: contractOwnerAccount, gas: 400000});
while (txpool.status.pending > 0) {
}
printTxData("fillTx", fillTx);
printBalances();
failIfGasEqualsGasUsed(fillTx, fillMessage);
printDctContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var sealMessage = "Seal Contract";
// -----------------------------------------------------------------------------
console.log("RESULT: " + sealMessage);
var sealTx = dct.seal({from: contractOwnerAccount, gas: 400000});
while (txpool.status.pending > 0) {
}
printTxData("sealTx", sealTx);
printBalances();
failIfGasEqualsGasUsed(sealTx, sealMessage);
printDctContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var canTransferMessage = "Can Move Tokens";
console.log("RESULT: " + canTransferMessage);
var canTransfer1Tx = dct.transfer(account5, "1000000000000", {from: account3, gas: 100000});
var canTransfer2Tx = dct.approve(account6,  "30000000000000000", {from: account4, gas: 100000});
while (txpool.status.pending > 0) {
}
var canTransfer3Tx = dct.transferFrom(account4, account7, "30000000000000000", {from: account6, gas: 100000});
while (txpool.status.pending > 0) {
}
printTxData("canTransfer1Tx", canTransfer1Tx);
printTxData("canTransfer2Tx", canTransfer2Tx);
printTxData("canTransfer3Tx", canTransfer3Tx);
printBalances();
failIfGasEqualsGasUsed(canTransfer1Tx, canTransferMessage + " - transfer 0.000001 BET ac3 -> ac5. CHECK for movement");
failIfGasEqualsGasUsed(canTransfer2Tx, canTransferMessage + " - ac4 approve 0.03 BET ac6");
failIfGasEqualsGasUsed(canTransfer3Tx, canTransferMessage + " - ac6 transferFrom 0.03 BET ac4 -> ac7. CHECK for movement");
printDctContractDetails();
console.log("RESULT: ");

EOF
grep "DATA: " $TEST1OUTPUT | sed "s/DATA: //" > $DEPLOYMENTDATA
cat $DEPLOYMENTDATA
grep "RESULT: " $TEST1OUTPUT | sed "s/RESULT: //" > $TEST1RESULTS
cat $TEST1RESULTS
