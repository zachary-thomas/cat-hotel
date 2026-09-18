using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation
{
    [CreateAssetMenu(menuName="Purrington/Meadow definition")]
    public sealed class MeadowDefinition : ScriptableObject
    {
        public HotelState starterHotel;
    }
}
