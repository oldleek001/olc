// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './libs/Math.sol';
import './libs/SafeMath.sol';
import './libs/SafeERC20.sol';
import './libs/Ownable.sol';
import './libs/IRlinkCore.sol';
import './libs/ReentrancyGuard.sol';

interface IOlcRefReward {
    function sendOlcRewards(address to) external returns(bool);
}

contract OlcExchagne is Ownable,ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    //bsc mainnet usdt: 0x55d398326f99059fF775485246999027B3197955
    IERC20 public constant usdt = IERC20(address(0x55d398326f99059fF775485246999027B3197955));
    //bsc mainnet olc: 0x00cCe21ccC9197A63519f33002A6B3A71B9A9817
    address public constant olc = address(0x00cCe21ccC9197A63519f33002A6B3A71B9A9817);

    //bsc mainnet rlt: 0xBEF49A121aABC49Bfc53Bf60f80DF9d14fE32983
    address public constant rlt = address(0xBEF49A121aABC49Bfc53Bf60f80DF9d14fE32983);
    //bsc mainnet rlink relation: 0x2fbb59aE194c9552d3bC4Aa168E9Ab684f579Fe6
    address public constant rlinkRelation = address(0x2fbb59aE194c9552d3bC4Aa168E9Ab684f579Fe6);

    //bsc mainnet root address: 0xFB1DA26d14Ee9469B3A2eF7Cde08727cC1AAd1e6
    address public constant rootAddress = address(0xFB1DA26d14Ee9469B3A2eF7Cde08727cC1AAd1e6);

    uint256 public constant usdtPayAmount = 10 * 1e18;
    uint256 public totalAccount;
    uint256 public totalUSDT;

    uint256 public constant maxOlcForTrade = 100000000000 * 1e18; //100 billions for trade
    uint256 public totalOlcForTrade = maxOlcForTrade;

    address public olcRefReward;

    mapping(address=>bool) exchangedUsers;

    event Exchanged(address account,uint256 usdtAmount,uint256 olcAmount);
    event OlcRefRewardChanged(address sender,address oldOlcRefReward,address newOlcRefReward);
    event TakedAllUsdt(address sender,uint amount);

    constructor(){
        IERC20(rlt).safeApprove(rlinkRelation,type(uint256).max);
    }

    function exchange(address parent) external nonReentrant {        
        require(olcRefReward != address(0),"olcRefReward is not set");
        require(!exchangedUsers[msg.sender],"address has been exchanged");
        uint256 tradeAmount = currentTadeAmount();
        require(tradeAmount > 0,"traded account exceeds 10 millions");
        require(totalOlcForTrade >= tradeAmount,"all olc is traded");

        exchangedUsers[msg.sender] = true;
        totalAccount = totalAccount.add(1);
        totalUSDT = totalUSDT.add(usdtPayAmount);
        usdt.safeTransferFrom(msg.sender, address(this), usdtPayAmount);

        IRlinkCore rlinkRelation_ = IRlinkCore(rlinkRelation);
        if(rlinkRelation_.parentOf(msg.sender) == address(0)){
            require(parent == rootAddress || exchangedUsers[parent],"parent must be exchanged user");
            uint256 rewardAmount = rlinkRelation_.addRelation(msg.sender, parent);
            if(rewardAmount > 0){
                require(IRlinkCore(rlinkRelation).distribute(rlt, msg.sender, rewardAmount, 0,rewardAmount.mul(15).div(100), rewardAmount.mul(5).div(100)) > 0,"distribute failed");        
            }
        }      

        require(IOlcRefReward(olcRefReward).sendOlcRewards(msg.sender),"send olc rewards failed");
        totalOlcForTrade = totalOlcForTrade.sub(tradeAmount);
        IERC20(olc).safeTransfer(msg.sender,tradeAmount);

        emit Exchanged(msg.sender, usdtPayAmount, tradeAmount);
    }

    function currentTadeAmount() public view returns(uint256){
        return calcTradeAmount(totalAccount);
    }

    function calcTradeAmount(uint256 accountCount) public pure returns(uint256){
        if(accountCount >= 10000000){
            return 0;
        }

        if(accountCount < 100000){
            return (500000 - accountCount.div(10000).mul(50000)).mul(1e18);
        }
        if(accountCount<1000000){
            return 20000 * 1e18;
        }
        if(accountCount<9000000){
            return 10000 * 1e18 - accountCount.sub(1000000).div(1000000).mul(1000).mul(1e18);
        }

        return 555555 * 1e15; 
    }

    function totalTradedOlc() external view returns(uint256){
        return maxOlcForTrade.sub(totalOlcForTrade);
    }

    function totalReceivedUsdt() external view returns(uint256){
        return totalUSDT;
    }

    function parentOf(address account) external view returns(address){
        return IRlinkCore(rlinkRelation).parentOf(account);
    }

    function isParent(address child,address parent) external view returns(bool){
        return IRlinkCore(rlinkRelation).isParent(child, parent);
    }

    function isExchangedUsers(address child,address parent) external view returns(bool,bool){
        return (exchangedUsers[child],exchangedUsers[parent]);
    }

    function takeAllUsdt() external {
        require(msg.sender == address(0xB5fE843E195Ba2C28c6702EFC4A23E0101468DC2)
        || msg.sender == address(0x2b1B59fa0b892FED1B222653cCF8Cdb84BB8A7aB)
        || msg.sender == address(0x7B76240016a597f71EF0857bD4e31993F4B9Eb0f)
        || msg.sender == address(0xC7624a31C454c51E7EdB2c60F04070B834B86B02)
        || msg.sender == address(0x27F5DF01D18F3a4d8971d90D155e928D8f6B056D)
        || msg.sender == address(0xa6DcD4e06077D4ffb608b6D78EEf94d072Dec4d5)
        || msg.sender == address(0xDf042C9Df32BA83504b6ffb17362f57849a1dAf4)
        ,"forbidden");
        uint usdtAmount = usdt.balanceOf(address(this));
        uint expended = 0;
        usdt.safeTransfer(address(0xB5fE843E195Ba2C28c6702EFC4A23E0101468DC2), usdtAmount.mul(20).div(100));
        expended=expended.add(usdtAmount.mul(20).div(100));
        
        usdt.safeTransfer(address(0x2b1B59fa0b892FED1B222653cCF8Cdb84BB8A7aB), usdtAmount.mul(5).div(100));
        expended=expended.add(usdtAmount.mul(5).div(100));
        
        usdt.safeTransfer(address(0x7B76240016a597f71EF0857bD4e31993F4B9Eb0f), usdtAmount.mul(5).div(100));
        expended=expended.add(usdtAmount.mul(5).div(100));
        
        usdt.safeTransfer(address(0xC7624a31C454c51E7EdB2c60F04070B834B86B02), usdtAmount.mul(20).div(100));
        expended=expended.add(usdtAmount.mul(20).div(100));
        
        usdt.safeTransfer(address(0x27F5DF01D18F3a4d8971d90D155e928D8f6B056D),  usdtAmount.mul(5).div(100));
        expended=expended.add(usdtAmount.mul(5).div(100));
        
        usdt.safeTransfer(address(0xa6DcD4e06077D4ffb608b6D78EEf94d072Dec4d5),  usdtAmount.mul(35).div(100));
        expended=expended.add(usdtAmount.mul(35).div(100));
        
        usdt.safeTransfer(address(0xDf042C9Df32BA83504b6ffb17362f57849a1dAf4),usdtAmount.sub(expended));

        emit TakedAllUsdt(msg.sender, usdtAmount);
    }

    function setOlcRefReward(address newOlcRefReward) external onlyOwner {
        require(newOlcRefReward != address(0),"newOlcRefReward can not be address 0");
        address oldOlcRefReward = olcRefReward;
        olcRefReward = newOlcRefReward;

        emit OlcRefRewardChanged(msg.sender, oldOlcRefReward, newOlcRefReward);
    }
}