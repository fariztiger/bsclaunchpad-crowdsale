// SPDX-License-Identifier: MIT;
pragma solidity ^0.7.0;

import "./libraries/SafeBEP20.sol";
import "./libraries/SafeMath.sol";
import "./validation/CappedCrowdsale.sol";
import "./validation/Whitelist.sol";
import "./BSCPAD.sol";

contract BSCLaunchPadCrowdsale is CappedCrowdsale,Whitelist {

 // set library are you using.
 using SafeERC20 for BSCPAD;      
 using SafeMath for uint256;

 // set Contract Instance
 BSCPAD public bscpad;

 // address where funds collected
 address payable public wallet;

 // set rate 1 BNB = ? BSCPAD
 uint256 public rate;

 // weiRaised in Crowdsale
 uint256 public weiRaised;

 // investorMaxCap for maximum contribution
 uint256 public investorMaxCap;

 // mapping for contributors
 mapping (address => uint256) contributors;   

 // called when hardCap got reached.
 bool public hasClosed;

 // market address
 address public marketAddress;

 // event for TokenPurchase
 event TokenPurchase(
     address indexed purchaser,
     address indexed beneficiary,
     uint256 bnbValue,
     uint256 tokens
 );

 // call the constructor for initial crowdsale

 constructor(
    uint256 _rate,
    address payable _wallet,
    address _bscPad,
    uint256 _softCap,
    uint256 _hardCap,
    uint256 _investorMaxCap,
    address _marketAddress
 ) CappedCrowdsale(_softCap,_hardCap) {
     // set the state of rate 
     rate = _rate;

     // set the instance of dbot token
     dbot = BSCPAD(_bscPad);

     // set Address for collecting ETH.
     wallet = _wallet;

     // set maximum cap giving by the investor.
     investorMaxCap = _investorMaxCap;

     // set market address state
     marketAddress = _marketAddress;
 }   

 // dont forget to receive ethers;
 receive() external payable {}
 
 // get current rate from the ico.
 function getCurrentRate() public view returns(uint256) {
     return rate;
 } 

 // get Converted token 1 ETH = 1500 DBOT;    
 function getTokenAmount(uint256 _weiValue) public view returns(uint256 expectedTokens) {
     // get expected tokens for _weiValue;
     expectedTokens = _weiValue.mul(rate);
 } 

 // buyTokens with ETH/ 1500     
 function buyTokens(address _beneficiary) external payable isWhiteListed(_beneficiary) {
    
    // validate the post behaviour of crowdsale
    _preValidatePurchase(msg.sender,_beneficiary,msg.value);

    // calcaulate token should be created.
    uint256 _expectedTokens = getTokenAmount(msg.value);

    // update the weiRaised
    weiRaised.add(_expectedTokens);

    // process the purchase
    _processPurchase(_beneficiary,_expectedTokens);

    // emit the event after transfer the tokens
    emit TokenPurchase(
        msg.sender,
        _beneficiary,
        msg.value,
        _expectedTokens
        );
    // forward the fund to the multisig wallet
    wallet.transfer(msg.value);

 }

 // check if cap get reach the goal.
 function capReached() internal view returns(bool){
     return (weiRaised >= hardCap || hasClosed); 
 }
 
 // pre-validation for checking
 function _preValidatePurchase(address payable _purchaseHodl,address _beneficiary,uint256 _investorAmount) internal isWhiteListed(_beneficiary) {
     // validate the pre-request
     require(_beneficiary != address(0),"PREVALIDATION: Invalid beneficiary address.");
     require(_investorAmount != 0,"PREVALIDATION: Invalid BNB.");
     require(investorMaxCap > _investorAmount, "PREVALIDATION: Invalid Amount.");
     // check if has achive the cap it will refunds the ETH fund.
     if(capReached()){
     // refund the eth back to the user when hard cap met;
     _purchaseHodl.transfer(_investorAmount);    
     // revert the transaction refund ethereum to the investor. 
     revert("PREVALIDATION: Hard cap gets reached!");
     }
 }

 // process the purchase init.   
 function _processPurchase(address _beneficiary, uint256 _tokenValue) internal {
     // add candidate to the contributors mapping.
     contributors[_beneficiary] = contributors[_beneficiary].add(_tokenValue);
     // transfer the tokens investor owned. but the DBOT contract owner must be crowdsale Contract.
     dbot.safeTransfer(_beneficiary, _tokenValue);
 }

 // function for get Contribution.
 function getContributions(address _beneficiary) public view returns(uint256){
   return contributors[_beneficiary];  
 }

 // last function that will be called after the crowdsale has been done.
 // 
 function finishlized(address _router, uint256 _deadline) external payable onlyOwner returns(uint256 amountToken,uint256 amountETH, uint256 liquidity) {
    // first check require the  condition that it will between softcap and hardcap.
    require(weiRaised >= softCap && weiRaised <= hardCap, "CROWDSALE: Finzation Error Cant' Achive SoftCap.");
    // if condition will true. that gather 40% eth.
    uint256 amountETHDesired = msg.value;
    // now you can add liquidity into the pool.
    IUniswapRouter02 router = IUniswapRouter02(_router);
    
    // tokenNomics of DBOT.
    /*
    8,000,00 totalSupply.
    525,000 presale supply.
    210,000 uniswap liduidity tokens.
    65,000 marketing supply tokens.
     */

    // distribute market tokens.
    uint256 marketTokens = 65000 ether;
    
    // approve router to access tokens
    uint256 liquidityTokens = 210000 ether;
    
    //distribute the market tokens on that address.
    dbot.safeTransfer(marketAddress, marketTokens);
    
    // give allowance to expand this tokens
    dbot.approve(_router,liquidityTokens);

    // add liquidity into token pool.
    (amountToken,amountETH,liquidity) = router.addLiquidityETH{value: amountETHDesired}(
        address(dbot), 
        liquidityTokens,
        1, 
        1, 
        msg.sender,
        _deadline
    );

    // now deal with remaining tokens that will be burned.
    // burn dust tokens.
    // presale allocation. 
    uint256 presale = 525000 ether;
    uint256 burnedTokens = presale.sub(weiRaised);
    _burnDustTokens(burnedTokens);

    // finally update the state of hasClosed.
    hasClosed = true;
    // make owner to the msg.sender of that contract
    dbot.transferOwnership(msg.sender);

 }

 function _burnDustTokens(uint256 burnedTokens) internal {
     // transfer that token into address(0) burn.
     dbot.burn(address(this), burnedTokens);
 }    

}