// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "../piglet/IPigletz.sol";
import "../token/PiFiToken.sol";
import "../oracle/IOracle.sol";
import "./PigletzMysteryBox.sol";

import "../utils/Discounts.sol";

import "../pancakeswap/IPancakeRouter02.sol";
import "../pancakeswap/IPancakePair.sol";

import "../pancakeswap/IPancakeFactory.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract SalesManager is Ownable, Pausable, ERC721Holder {
    using Discounts for bytes;

    IPigletz public immutable pigletz;
    PiFiToken public immutable pifi;
    PigletzMysteryBox public mysteryBox;

    uint256[] _prices;
    uint256[] _amounts;
    uint256 _totalAvailableForPurchase;
    uint256 _purchases;
    uint256 _maxPrice;

    uint256[6] _discounts = [0, 1000, 2000, 3000, 4000, 5000];

    IPancakeRouter02 immutable _router;
    bool private _isPoolCreated = false;

    uint256 constant PIFI_PER_SALE = 10000 ether;
    uint256 constant PIPS = 10000;
    address _discountSigner;

    constructor(
        IPigletz _pigletz,
        IPancakeRouter02 router,
        PiFiToken _pifi,
        uint256 maxPrice
    ) {
        pigletz = _pigletz;
        pifi = _pifi;

        _router = router;
        _maxPrice = maxPrice;
        _pause();
    }

    event PigletPurchase(
        address indexed buyer,
        uint256 indexed discountId,
        uint16 indexed affiliateId,
        uint16 nonce,
        uint256 originalPrice,
        uint256 price,
        uint256 count
    );
    event BalanceWithdrawn(address indexed caller, address indexed recepient, uint256 amount);
    event LiquidityWithdrawn(address indexed caller, address indexed recepient, uint256 amount);
    event LiquidityPoolCreated(address indexed caller, uint256 ethAmount, uint256 pifiAmount);
    event LiquidityPoolCreationFailed(address indexed caller, string reason);

    function setMysteryBoxContract(address box) external onlyOwner {
        mysteryBox = PigletzMysteryBox(box);
    }

    function _getPrice(uint256 amount) internal view returns (uint256) {
        uint256 total = 0;
        uint256 count = 0;
        uint256 cur = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            count += _amounts[i];
            while (_purchases + cur < count) {
                total += _prices[i];
                cur++;
                if (cur == amount) {
                    return total;
                }
            }
        }
        revert("invalid amount");
    }

    function getPurchasePrice(uint256 amount, bytes calldata discountCode) public view returns (uint256, uint256) {
        require(amount + _purchases <= _totalAvailableForPurchase, "Not enough piglets available for purchase");

        uint8 discountId = _getDiscount(discountCode, amount);

        uint256 price = _getPrice(amount);

        uint256 discountedPrice = ((price * (PIPS - _discounts[discountId]))) / PIPS;

        return (price, discountedPrice);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _arePigletzLeftForPurchase(uint256 amount) internal view returns (bool) {
        uint256 numReserved = address(mysteryBox) == address(0) ? 0 : mysteryBox.getTotalNumberOfPiglets();
        return numReserved + amount + pigletz.tokenCount() <= pigletz.maxSupply();
    }

    function purchase(uint256 amount, bytes calldata discountCode) external payable whenNotPaused {
        require(amount == 1 || amount == 5 || amount == 10 || amount == 20, "Amount must be 1, 5, 10 or 20");
        require(amount + _purchases <= _totalAvailableForPurchase, "Not enough piglets available for purchase");
        require(_arePigletzLeftForPurchase(amount), "Not enough piglets available for purchase");

        (uint256 originalPrice, uint256 purchasePrice) = getPurchasePrice(amount, discountCode);
        require(msg.value >= purchasePrice, "Insufficient funds");

        uint256 probabilityOfSpecial = (msg.value * PIPS) / (amount * _maxPrice);
        pigletz.mint(msg.sender, amount, probabilityOfSpecial);
        _purchases += amount;

        (uint16 aff, uint8 id, uint16 nonce) = (0, 0, 0);
        if (discountCode.length > 0) {
            (, aff, id, , , nonce, ) = discountCode.parseDiscountCode();
        }
        emit PigletPurchase(msg.sender, id, aff, nonce, originalPrice, purchasePrice, amount);
    }

    function _getDiscount(bytes calldata discountCode, uint256 amount) internal view returns (uint8) {
        if (discountCode.length == 0) {
            return 0;
        }

        (uint16 magic, , uint8 id, uint16 start, uint16 end, , address signer) = discountCode.parseDiscountCode();

        require(start <= _purchases + 1 && _purchases + amount <= end, "Invalid range");
        require(_discountSigner != address(0) && signer == _discountSigner, "Invalid signer");
        require(id <= _discounts.length, "Invalid discount id");
        require(magic == 0xaff0, "Invalid magic");

        return id;
    }

    function mintCelebrities(address to) external onlyOwner {
        require(to != address(0), "Invalid address");
        pigletz.mintCelebrities(to);
    }

    function createCollection(uint256 price, uint256 count) public onlyOwner {
        require(price > 0, "Invalid price");
        require(count > 0, "Invalid count");
        _prices.push(price);
        _amounts.push(count);
        _totalAvailableForPurchase += count;
    }

    function withdrawBalance(address payable recipient) external onlyOwner {
        uint256 balance = address(this).balance;
        recipient.transfer(balance);

        emit BalanceWithdrawn(msg.sender, recipient, balance);
    }

    function getMaxPifiLPAmount() public view returns (uint256) {
        return _purchases * PIFI_PER_SALE;
    }

    function createPool(uint256 pifiAmount) external payable onlyOwner {
        require(!_isPoolCreated, "Pool already created");
        require(msg.value > 0, "insufficient funds");
        require(pifiAmount <= getMaxPifiLPAmount(), "pifi amount too high");

        pifi.mint(address(this), pifiAmount);
        pifi.approve(address(_router), pifiAmount);

        try
            _router.addLiquidityETH{ value: msg.value }(
                address(pifi),
                pifiAmount,
                pifiAmount,
                msg.value,
                address(this),
                block.timestamp + 20 minutes
            )
        {
            _isPoolCreated = true;
            emit LiquidityPoolCreated(msg.sender, msg.value, pifiAmount);
        } catch Error(string memory reason) {
            pifi.approve(msg.sender, pifiAmount);
            emit LiquidityPoolCreationFailed(msg.sender, reason);
        }
    }

    function withdrawLPBalance(address recipient) external onlyOwner {
        require(_isPoolCreated, "pool not created");

        IPancakeFactory factory = IPancakeFactory(_router.factory());
        IPancakePair pair = IPancakePair(factory.getPair(address(pifi), _router.WETH()));
        uint256 balance = pair.balanceOf(address(this));
        pair.transfer(recipient, balance);

        emit LiquidityWithdrawn(msg.sender, recipient, balance);
    }

    function getCollections()
        public
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            uint256
        )
    {
        return (_prices, _amounts, _purchases);
    }

    function getPurchasedCount() public view returns (uint256) {
        return _purchases;
    }

    function setDiscountSigner(address signer) public onlyOwner {
        require(signer != address(0), "Invalid signer");
        _discountSigner = signer;
    }
}
